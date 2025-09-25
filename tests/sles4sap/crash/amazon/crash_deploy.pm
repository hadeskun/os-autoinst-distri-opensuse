# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: This module is responsible for creating all necessary AWS resources:
# It saves VM public IP and SSH command into job variables

use base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
#use sles4sap::aws_cli;
use utils;
use version_utils;


sub run {
    my ($self) = @_;

    die('AWS is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');

    my $aws_prefix = get_var('DEPLOY_PREFIX', 'clne');
    my $job_id = $aws_prefix . get_current_job_id();

    select_serial_terminal;
    if (script_run("which aws") != 0) {
        zypper_call 'in aws-cli jq';
    }

    my $provider = $self->provider_factory();

    my $os_ver;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        $os_ver = $provider->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_ver = $provider->get_image_id();
    }

    record_info("OS",$os_ver);
    assert_script_run('rm ~/.ssh/config');

    

    set_var('VM_IP', $vm_ip);
    set_var('SSH_CMD', $ssh_cmd);
    set_var('VM_NAME', $vm);
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
}

1;
