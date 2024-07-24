# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup system with podman ,docker and reset network
# Maintainer: QE-SAP team

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(check_os_release get_os_release is_sle is_sle_micro);
use containers::common;
use containers::utils qw(reset_container_network_if_needed);

sub run {
    select_serial_terminal;
    my ($version, $sp, $host_distri) = get_os_release;
    my $engine = get_required_var('CONTAINER_RUNTIMES');

    # Install engines in case they are not installed
    install_docker_when_needed($host_distri) if ($engine =~ 'docker');
    install_podman_when_needed($host_distri) if ($engine =~ 'podman');
    reset_container_network_if_needed($engine);

    # Record podman|docker version
    foreach my $eng (split(',\s*', $engine)) {
        record_info($eng, script_output("$eng info"));
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
