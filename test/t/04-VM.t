use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::MockModule;
use LML::Common;

# load shipped configuration
LoadConfig( "src/lml/default.conf", "test/data/test.conf" );

# mock needed function from LML::VMware
use LML::VMware;
my $mock            = new Test::MockModule('LML::VMware');
my $off_value       = undef;
my $extraopts_key   = undef;
my $extraopts_value = undef;

$mock->mock(
    'get_vm_data',
    sub {
        my $uuid   = shift;
        my %VM_ALL = %{ ReadVmFile() };

        #diag("Mock get_vm_data($uuid):\n");
        return () unless ( exists $VM_ALL{$uuid} );
        return %{ $VM_ALL{$uuid} };

    }
);

$mock->mock(
    'setVmCustomValueU',
    sub {
        my $uuid            = shift;
        my $forceboot_field = shift;
        $off_value = shift;

        #diag("Mock setVmCustomValueU($uuid,$forceboot_field,$off_value)\n");
        return 1;
    }
);

$mock->mock(
    'setVmExtraOptsU',
    sub {
        my $uuid;
        ( $uuid, $extraopts_key, $extraopts_value ) = @_;
        #diag("Mock setVmExtraOptsU($uuid,$extraopts_key,$extraopts_value)\n");
        return 1;
    }
);
use_ok "LML::VM";

my $VM;
warning_like { $VM = new LML::VM() } qr(Give the VM uuid as arg), "contructor should fail on missing argument";
is( $VM,                           undef, "failed constructor should return undef" );
is( new LML::VM("foobar"), undef, "constructor should return undef if no VM found for given uuid" );

$VM = new LML::VM("4213038e-9203-3a2b-ce9d-c6dac1f2dbbf");
my %VM_DATA = (LML::VMware::get_vm_data("4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"), "filter_networks", []);
is_deeply( \%VM_DATA, $VM, "constructor should return hashref with VM datails" );

is( $VM->uuid, "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf", "uuid method should return uuid" );

is( $VM->name, "tsthst001", "name method should return VM name" );

is_deeply( [ $VM->get_macs() ], [ '01:02:03:04:6e:4e', '01:02:03:04:9e:9e' ], "Get_macs should return a list of mac addresses" );
is_deeply( [ $VM->get_filtered_macs ], [$VM->get_macs() ], "get_macs_for_networks should return all macs if no filter set" );
$VM->set_networks_filter("baz", "foo.bar");
is_deeply( [ $VM->get_filtered_macs( ) ], [], "should return empty list if called after setting non-matching networks filter" );
$VM->set_networks_filter("arc.int");
is_deeply( [ $VM->get_filtered_macs ], ["01:02:03:04:6e:4e"], "should return matching mac after setting matching network as filter" );
$VM->set_networks_filter("arc.int", "foo.bar");
is_deeply( [ $VM->get_filtered_macs ], ["01:02:03:04:6e:4e"], "should return matching mac after setting list containing the right network as filter" );

ok( $VM->forcenetboot,                                                           "should return that forcenetboot is active for managed VM" );
ok( !LML::VM->new("4213c435-a176-a533-e07e-38644cf43390")->forcenetboot, "should return that forcenetboot is not active for unmanaged VM" );

ok ($VM->activate_forcenetboot,"should not fail activating force net boot");
ok (($extraopts_key eq "bios.bootDeviceClasses" and $extraopts_value eq "allow:net"),"should have used the correct vSphere setting to actually force only net boot");
done_testing();
