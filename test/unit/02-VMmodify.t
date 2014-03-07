#use strict;
use warnings;

use Test::More;

use Test::Exception;
use LML::Config;
use LML::Common;

# load shipped configuration
my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

use Test::MockModule;
use LML::VMware;
my $mock      = new Test::MockModule('LML::VMware');
my $off_value = undef;

my $VM_ALL = {
               "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
                                                          "CUSTOMFIELDS" => {
                                                                              "Contact User ID" => "User2",
                                                                              "Expires"         => "31.01.2013",
                                                                              "Force Boot"      => ""
                                                          },
                                                          "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
                                                          "MAC"          => {
                                                                     "01:02:03:04:6e:4e" => "arc.int",
                                                                     "01:02:03:04:9e:9e" => "foo"
                                                          },
                                                          "NAME"       => "tsthst001",
                                                          "HOST"       => "testesx01.domain",
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
                                                          "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
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

use_ok "LML::VMmodify";

#$isDebug = 1;    # tell us why it did not work
dies_ok { remove_forceboot( $C, "" ) } "should fail on empty uuid";
ok( remove_forceboot( $C, "123123123-124123-23421342-2341234234" ), "should not fail with non-existant uuid" );

ok( remove_forceboot( $C, '4213038e-9203-3a2b-ce9d-c6dac1f2dbbf' ),
    "old style, no force boot target field, set empty value" );
is( $off_value, "", "old style, no force boot target field, value should be empty" );

ok( remove_forceboot( $C, "4213038e-9203-3a2b-ce9d-123456789abc" ),
    "new style, with force boot target field, set OFF value" );
is( $off_value, "OFF", "new style with force boot target, value should be OFF" );

$CONFIG{'vsphere'}{'forceboot_field'} = undef;
ok( !remove_forceboot( $C, '4213038e-9203-3a2b-ce9d-c6dac1f2dbbf' ), "should fail as forceboot_field is not set" );

done_testing;
