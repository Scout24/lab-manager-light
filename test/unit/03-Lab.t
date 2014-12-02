use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Exception;
use File::Slurp;
use Data::Dumper;

use LML::Config;

use LML::Common;
#$isDebug=1;

my $VM_ALL = {
                    "42130272-a509-8010-6e85-4e01cb1b7284" => {
                                                          "BOOTORDER" => [],
                                                          "CUSTOMFIELDS" => {
                                                                              "Contact User ID" => "User1",
                                                                              "Expires"         => "31.12.2013"
                                                          },
                                                          "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
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
};

# we use the following here to mock it, it is basically only used within Lab
use LML::VMware;

my $mock            = new Test::MockModule('LML::VMware');
$mock->mock(
    get_vm_data =>
    sub {
        my $uuid = shift;
        #diag("Mock get_vm_data($uuid):\n");
        return \() unless ( exists $VM_ALL->{$uuid} );
        return $VM_ALL->{$uuid};

    } );
use LML::VM;
use_ok "LML::Lab";

dies_ok { new LML::Lab("/dev/null") } "should die on reading invalid LAB file";

# load test config
my $C = new_ok( "LML::Config" => [ "src/lml/default.conf", "test/data/test.conf" ] );

my %LAB_TESTDATA = (
    "HOSTS" => {
                 "4213059e-70c2-6f34-1986-50463d0222f8" => {
                                                             "HOSTNAME"         => "tstgag002",
                                                             "LASTSEEN"         => "1354790575",
                                                             "LASTSEEN_DISPLAY" => "Thu Dec  6 11:42:55 2012",
                                                             "MACS"             => ["01:02:03:04:69:b0"],
                                                             # DNS_DOMAIN is NOT set here to test migration
                                                             "EXTRAOPTS"        => "option foo2 \"bar2\"",
                 },
                 "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
                                                             "HOSTNAME"         => "tsthst001",
                                                             "LASTSEEN"         => "1351688243",
                                                             "LASTSEEN_DISPLAY" => "Wed Oct 31 13:57:23 2012",
                                                             "MACS"             => ["01:02:03:04:6e:4e"],
                                                             "DNS_DOMAIN"       => "other.domain",
                                                             "IP"               => "1.2.3.4",
                                                             "VM_ID"            => "vm-1000",
                                                             "EXTRAOPTS"        => "option foo \"bar\";option bar baz;",
                 } }

);

#write test data to lab file

write_file( $C->labfile, Data::Dumper->Dump( [ \%LAB_TESTDATA ], [qw(LAB)] ) );

my $roLAB = new_ok( "LML::Lab" => [ $C->labfile ], "should create new readonly Lab object" );
dies_ok { $roLAB->write_file(__FILE__) } "should fail writing a read-only Lab object";

# test if we can load config from config files
my $LAB = new_ok( "LML::Lab" => [ $C->labfile, "1" ], "should create new readwrite Lab object" );

is( $LAB->{HOSTS}{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{HOSTNAME},
    "tsthst001", "LAB should contain hostname from test data" );
my $VM = new LML::VM( {
                        "BOOTORDER" => [],
                        "CUSTOMFIELDS" => {
                                            "Contact User ID" => "User2",
                                            "Expires"         => "31.01.2013",
                                            "Force Boot"      => ""
                        },
                        "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
                        "MAC"          => {
                                   "99:02:03:04:6e:4e" => "arc.int",
                                   "99:02:03:04:9e:9e" => "foo"
                        },
                        "NAME"       => "tsthst001",
                        "NETWORKING" => [ {
                                            "MAC"     => "99:02:03:04:6e:4e",
                                            "NETWORK" => "arc.int"
                                          },
                                          {
                                            "MAC"     => "99:02:03:04:9e:9e",
                                            "NETWORK" => "foo"
                                          }
                        ],
                        "PATH"  => "development/vm/otherpath/tsthst001",
                        "VM_ID" => "vm-1000",
                        "UUID"  => "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf",
                      } );
$VM->set_networks_filter( $C->get_array("vsphere","networks") );    # set network filter
is(
    $LAB->update_vm($VM),
    1,
    "should return 1 to indicate that the VM changed some data that is DHCP relevant"
);
is_deeply( [ $LAB->vms_to_update ],
           ["4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"],
           "should return the uuid of the changed VM" );
is_deeply( $LAB->{HOSTS}{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{MACS},
           ["99:02:03:04:6e:4e"], "should copy only MACS of managed networks" );

$LAB->set_filename("test/temp/new_lab.conf");
is(
    $LAB->write_file( "by " . __FILE__, "test" ),
    3342,
"Writing to 'test/temp/new_lab.conf' should write 3169 bytes and it would be better to analyse the content but at least we notice change"
);

done_testing();
