# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman integration
# Summary: Upstream podman integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::utils qw(get_podman_version);
use utils qw(script_retry);
use version_utils qw(is_sle is_sle_micro is_tumbleweed is_microos is_leap is_leap_micro);
use containers::common;
use Utils::Architectures qw(is_x86_64 is_aarch64);
use containers::bats qw(install_bats remove_mounts_conf switch_to_user delegate_controllers);

my $test_dir = "/var/tmp";
my $podman_version = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $remote, $skip_tests) = ($params{rootless}, $params{remote}, $params{skip_tests});

    my $log_file = "bats-" . ($rootless ? "user" : "root") . "-" . ($remote ? "remote" : "local") . ".tap";
    my $args = ($rootless ? "--rootless" : "--root");
    $args .= " --remote" if ($remote);

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    assert_script_run "cp -r test/system.orig test/system";
    my @skip_tests = split(/\s+/, get_required_var('PODMAN_BATS_SKIP') . " " . $skip_tests);
    script_run "rm test/system/$_.bats" foreach (@skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    background_script_run "podman system service --timeout=0" if ($remote);
    script_run "env PODMAN=/usr/bin/podman QUADLET=$quadlet hack/bats $args | tee -a $log_file", 3600;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test/system";
    script_run 'kill %1' if ($remote);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns catatonit gpg2 jq make netavark netcat-openbsd openssl podman podman-remote python3-passlib python3-PyYAML skopeo socat sudo systemd-container);
    push @pkgs, qw(buildah) unless is_sle_micro;
    push @pkgs, qw(criu passt) if (is_tumbleweed || is_microos || is_sle_micro('>=6.0') || is_leap_micro('>=6.0'));
    # Needed for podman machine
    if (is_x86_64) {
        push @pkgs, "qemu-x86";
    } elsif (is_aarch64) {
        push @pkgs, "qemu-arm";
    }
    install_packages(@pkgs);

    assert_script_run "curl -o /usr/local/bin/htpasswd " . data_url("containers/htpasswd");
    assert_script_run "chmod +x /usr/local/bin/htpasswd";

    delegate_controllers;

    assert_script_run "podman system reset -f";
    assert_script_run "modprobe ip6_tables";

    remove_mounts_conf;

    switch_cgroup_version($self, 2);

    record_info("podman info", script_output("podman info"));

    switch_to_user;

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download podman sources
    $podman_version = get_podman_version();
    script_retry("curl -sL https://github.com/containers/podman/archive/refs/tags/v$podman_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run("cd $test_dir/podman-$podman_version/");
    assert_script_run "sed -i 's/bats_opts=()/bats_opts=(--tap)/' hack/bats";
    assert_script_run "cp -r test/system test/system.orig";

    # user / local
    run_tests(rootless => 1, remote => 0, skip_tests => get_var('PODMAN_BATS_SKIP_USER_LOCAL', ''));

    # user / remote
    run_tests(rootless => 1, remote => 1, skip_tests => get_var('PODMAN_BATS_SKIP_USER_REMOTE', '')) unless (is_sle_micro('<5.5'));

    select_serial_terminal;
    assert_script_run("cd $test_dir/podman-$podman_version/");

    # root / local
    run_tests(rootless => 0, remote => 0, skip_tests => get_var('PODMAN_BATS_SKIP_ROOT_LOCAL', ''));

    # root / remote
    run_tests(rootless => 0, remote => 1, skip_tests => get_var('PODMAN_BATS_SKIP_ROOT_REMOTE', '')) unless (is_sle_micro('<5.5'));
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/podman-$podman_version/");
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;
