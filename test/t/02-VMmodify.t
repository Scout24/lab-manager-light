use strict;
use warnings;

use Test::More;
use Test::MockModule;
use LML::Common;

# load shipped configuration
LoadConfig( "src/lml/default.conf", "test/data/test.conf" );

# mock needed function from LML::VMware
use LML::VMware;
my $mock      = new Test::MockModule('LML::VMware');
my $off_value = undef;

$mock->mock(
    'get_vm_data',
    sub {
        my $uuid = shift;
        my %VM_ALL          = %{ ReadVmFile() };
        my %VM;
        $VM{$uuid} = $VM_ALL{$uuid} if (exists $VM_ALL{$uuid});
        #diag("Mock get_vm_data($uuid):\n");
        #diag(explain(\%VM));
        return %VM;
    }
);

$mock->mock(
    'setVmCustomValueU',
    sub {
        my $uuid     = shift;
        my $forceboot_field = shift;
        $off_value = shift;
        #diag("Mock setVmCustomValueU($uuid,$forceboot_field,$off_value)\n");
        return 1;
    }
);
use_ok "LML::VMmodify";

#$isDebug=1; # tell us why it did not work

ok (! remove_forceboot(""), "should fail on empty uuid");
ok (! remove_forceboot("123123123-124123-23421342-2341234234"), "should fail not non-existant uuid");

ok (remove_forceboot('4213038e-9203-3a2b-ce9d-c6dac1f2dbbf'), "old style, no force boot target field, set empty value");
is ($off_value,"","old style, no force boot target field, value should be empty");

ok (remove_forceboot("4213038e-9203-3a2b-ce9d-123456789abc"), "new style, with force boot target field, set OFF value");
is ($off_value,"OFF","new style with force boot target, value should be OFF");

$CONFIG{'vsphere'}{'forceboot_field'} = undef;
ok (! remove_forceboot('4213038e-9203-3a2b-ce9d-c6dac1f2dbbf'), "should fail as forceboot_field is not set");

done_testing;
