# SUSE's openQA tests
#
# Copyright 2020-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for podman specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::podman;
use strict;
use warnings;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url);
use containers::common qw(install_podman_when_needed);
use utils qw(file_content_replace);
has runtime => "podman";

sub init {
    install_podman_when_needed();
    configure_insecure_registries();
}

sub configure_insecure_registries {
    my ($self) = shift;

    assert_script_run "curl " . data_url('containers/registries.conf') . " -o /etc/containers/registries.conf";
    assert_script_run "chmod 644 /etc/containers/registries.conf";
    # Add custom registry only if set by the REGISTRY variable
    assert_script_run('echo -e \'[[registry]]\nlocation = "' . registry_url() . '"\ninsecure = true\' >> /etc/containers/registries.conf') if get_var('REGISTRY');
}

sub get_storage_driver {
    my $storage = script_output("podman info -f '{{.Store.GraphDriverName}}'");
    record_info 'Storage', "Detected storage driver=$storage";

    return $storage;
}

1;
