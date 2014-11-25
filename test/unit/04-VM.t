use strict;
use warnings;

use Test::More;
use Test::Warn;

use LML::Common;

# load shipped configuration
LoadConfig( "src/lml/default.conf", "test/data/test.conf" );

# mock needed function from LML::VMware
use Test::MockModule;
use LML::VMware;
my $mock            = new Test::MockModule('LML::VMware');
my $off_value       = undef;
my $extraopts_key   = undef;
my $extraopts_value = undef;
my $VM_ALL = {
                    "42130272-a509-8010-6e85-4e01cb1b7284" => {
                                                          "CUSTOMFIELDS" => {
                                                                              "Contact User ID" => "User1",
                                                                              "Expires"         => "31.12.2013"
                                                          },
                                                          "EXTRAOPTIONS" => {
                                                              "bios.bootDeviceClasses" => "allow:net,hd",
                                                              "bios.bootOrder" => "ethernet0,hdd" },
                                                          "MAC"          => { "01:02:03:04:00:15"      => "arc.int" },
                                                          "NAME"         => "lochst001",
                                                          "HOST"         => "testesx01.domain",
                                                          "NETWORKING"   => [ {
                                                                              "MAC"     => "01:02:03:04:00:15",
                                                                              "NETWORK" => "arc.int"
                                                                            }
                                                          ],
                                                          "PATH"  => "development/vm/path/lochst001",
                                                          "VM_ID" => "vm-0500",
                                                          "UUID"  => "42130272-a509-8010-6e85-4e01cb1b7284"
                    },
                    "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
                                                          "CUSTOMFIELDS" => {
                                                                              "Contact User ID" => "User2",
                                                                              "Expires"         => "31.01.2013",
                                                                              "Force Boot"      => ""
                                                          },
                                                          "EXTRAOPTIONS" => {
                                                              "bios.bootDeviceClasses" => "allow:net,hd",
                                                              "bios.bootOrder" => "ethernet0,hdd" },
                                                          "MAC"          => {
                                                                     "01:02:03:04:6e:4e" => "arc.int",
                                                                     "01:02:03:04:9e:9e" => "foo"
                                                          },
                                                          "NAME"       => "tsthst001",
                                                          "HOST"         => "testesx01.domain",
                                                          "NETWORKING" => [ {
                                                                              "MAC"     => "01:02:03:04:6e:4e",
                                                                              "NETWORK" => "arc.int"
                                                                            },
                                                                            {
                                                                              "MAC"     => "01:02:03:04:9e:9e",
                                                                              "NETWORK" => "foo"
                                                                            }
                                                          ],
                                                          "PATH"  => "development/vm/otherpath/tsthst001",
                                                          "VM_ID" => "vm-1000",
                                                          "UUID"  => "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"
                    },
                    "4213038e-9203-3a2b-ce9d-123456789abc" => {
                                                          "CUSTOMFIELDS" => {
                                                                              "Contact User ID"   => "User3",
                                                                              "Expires"           => "31.01.2010",
                                                                              "Force Boot"        => "garbage",
                                                                              "Force Boot Target" => "server"
                                                          },
                                                          "EXTRAOPTIONS" => {
                                                              "bios.bootDeviceClasses" => "allow:net,hd",
                                                              "bios.bootOrder" => "ethernet0,hdd" },
                                                          "MAC"          => { "01:02:03:04:6e:5c"      => "arc.int" },
                                                          "NAME"         => "tsthst099",
                                                          "HOST"         => "testesx01.domain",
                                                          "NETWORKING"   => [ {
                                                                              "MAC"     => "01:02:03:04:6e:5c",
                                                                              "NETWORK" => "arc.int"
                                                                            }
                                                          ],
                                                          "PATH"  => "development/vm/otherpath/tsthst099",
                                                          "VM_ID" => "vm-2000",
                                                          "UUID"  => "4213038e-9203-3a2b-ce9d-123456789abc"
                    },
                    "4213c435-a176-a533-e07e-38644cf43390" => {
                                                        "CUSTOMFIELDS" => {
                                                                            "Contact User ID" => "unrelated1",
                                                                            "Expires"         => "01.01.2015"
                                                        },
                                                        "MAC"        => { "01:02:03:04:2e:73" => "vlan_902" },
                                                        "NAME"       => "Some VM123",
                                                        "HOST"         => "testesx01.domain",
                                                        "NETWORKING" => [ {
                                                                            "MAC"     => "01:02:03:04:2e:73",
                                                                            "NETWORK" => "vlan_123"
                                                                          }
                                                        ],
                                                        "PATH" => "development/vm/Unrelated/VMPath/Web-Java/Some VM123",
                                                        "UUID" => "4213c435-a176-a533-e07e-38644cf43390",
                                                        "VM_ID" => "vm-9876"
                    } };

$mock->mock(
    'get_vm_data',
    sub {
        my $uuid = shift;
        #diag("Mock get_vm_data($uuid):\n");
        return \() unless ( exists $VM_ALL->{$uuid} );
        return $VM_ALL->{$uuid};

    } );

$mock->mock(
    'setVmCustomValue',
    sub {
        my $uuid            = shift;
        my $forceboot_field = shift;
        $off_value = shift;

        #diag("Mock setVmCustomValue($uuid,$forceboot_field,$off_value)\n");
        return 1;
    } );

$mock->mock(
    'setVmExtraOptsU',
    sub {
        my $uuid;
        ( $uuid, $extraopts_key, $extraopts_value ) = @_;
        #diag("Mock setVmExtraOptsU($uuid,$extraopts_key,$extraopts_value)\n");
        return 1;
    } );

use_ok "LML::VM";

my $VM;
warning_like { $VM = new LML::VM() } qr(Give the VM), "contructor should fail on missing argument";
is( $VM,                   undef, "failed constructor should return undef" );
is( new LML::VM("foobar"), undef, "constructor should return undef if no VM found for given uuid" );

$VM = new LML::VM("4213038e-9203-3a2b-ce9d-c6dac1f2dbbf");
# manually construct a VM object:
my $VM_DATA = LML::VMware::get_vm_data("4213038e-9203-3a2b-ce9d-c6dac1f2dbbf");
$VM_DATA->{"filter_networks"} = [];
is_deeply( $VM_DATA, $VM, "constructor should return hashref with VM datails" );

is( $VM->uuid, "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf", "uuid method should return uuid" );

is( $VM->name, "tsthst001", "name method should return VM name" );

is( $VM->vm_id, "vm-1000", "should return vm_id of VM" );

is_deeply( [ $VM->get_macs() ],
           [ '01:02:03:04:6e:4e', '01:02:03:04:9e:9e' ],
           "Get_macs should return a list of mac addresses" );

is_deeply( [ $VM->get_filtered_macs() ],
           [ $VM->get_macs() ],
           "get_filtered_macs should return all macs if no filter set" );

$VM->set_networks_filter( "baz", "foo.bar" );
is_deeply( [ $VM->get_filtered_macs() ],
           [], "should return empty list if called after setting non-matching networks filter" );

$VM->set_networks_filter("arc.int");
is_deeply( [ $VM->get_filtered_macs() ],
           ["01:02:03:04:6e:4e"], "should return matching mac after setting matching network as filter" );

$VM->set_networks_filter( "arc.int", "foo.bar" );
is_deeply( [ $VM->get_filtered_macs() ],
           ["01:02:03:04:6e:4e"],
           "should return matching mac after setting list containing the right network as filter" );

$VM->set_networks_filter( "arc.*", "foo.bar" );
is_deeply( [ $VM->get_filtered_macs() ],
           ["01:02:03:04:6e:4e"],
           "should return matching mac after setting list containing the right network as filter regex" );

is( $VM->path, "development/vm/otherpath/tsthst001", "should return the VM path" );

is_deeply(
           $VM->mac,
           {
              "01:02:03:04:6e:4e" => "arc.int",
              "01:02:03:04:9e:9e" => "foo"
           },
           "should return the mac table"
);

is_deeply(
           $VM->customfields,
           {
              "Contact User ID" => "User2",
              "Expires"         => "31.01.2013",
              "Force Boot"      => ""
           },
           "should return the customfields table"
);

is_deeply([$VM->networks()],["arc.int","foo"],"should return list of network labels");

ok( $VM->prefernetboot, "should return that prefernetboot is active for managed VM" );
ok( !LML::VM->new("4213c435-a176-a533-e07e-38644cf43390")->prefernetboot,
    "should return that prefernetboot is not active for unmanaged VM" );

ok( $VM->activate_prefernetboot, "should not fail activating force net boot" );
ok( ( $extraopts_key eq "bios.bootDeviceClasses" and $extraopts_value eq "allow:net,hd" ),
    "should have used the correct vSphere setting to actually force only net boot" );
done_testing();
