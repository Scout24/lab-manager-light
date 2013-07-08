use strict;
use warnings;

use Test::More;
use Test::MockModule;
use File::Slurp;
use LML::Config;
use LML::Common;
use LML::Lab;

# mock needed function from LML::VMware
#use LML::VMware;
#my $mock = new Test::MockModule('LML::VMware');
my $ESX_ALL = {
                "testesx01.domain" => {
                                             "id"      => "host-1060",
                                             "name"    => "testesx01.domain",
                                             "product" => {
                                                            "apiType"               => "HostAgent",
                                                            "apiVersion"            => "5.1",
                                                            "build"                 => 799733,
                                                            "fullName"              => "VMware ESXi 5.1.0 build-799733",
                                                            "licenseProductName"    => "VMware ESX Server",
                                                            "licenseProductVersion" => "5.0",
                                                            "localeBuild"           => "000",
                                                            "localeVersion"         => "INTL",
                                                            "name"                  => "VMware ESXi",
                                                            "osType"                => "vmnix-x86",
                                                            "productLineId"         => "embeddedEsx",
                                                            "vendor"                => "VMware, Inc.",
                                                            "version"               => "5.1.0"
                                             }
                },
};

#$mock->mock(
#    'get_hosts',
#    sub {
#        #diag("Mock get_hosts():\n");
#        return $ESX_ALL;
#
#    } );
require_ok "src/lml/tools/lml-maintenance.pl";

my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

# test the maintenance routine start by read out test data
my $VM_ALL = {
               "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
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
                                                           "HOST"       => "testesx01.domain",
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
                                                           "UUID"  => "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"
               },
};

my %LAB_TESTDATA = (
    "HOSTS" => {
                 "4213059e-70c2-6f34-1986-50463d0222f8" => {
                                                             "HOSTNAME"         => "tstgag002",
                                                             "LASTSEEN"         => "1354790575",
                                                             "LASTSEEN_DISPLAY" => "Thu Dec  6 11:42:55 2012",
                                                             "MACS"             => ["01:02:03:04:69:b0"],
                                                             "EXTRAOPTS"        => "option foo2 \"bar2\"",
                 },
                 "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
                                                             "HOSTNAME"         => "tsthst001",
                                                             "LASTSEEN"         => "1351688243",
                                                             "LASTSEEN_DISPLAY" => "Wed Oct 31 13:57:23 2012",
                                                             "MACS"             => ["01:02:03:04:6e:4e"],
                                                             "IP"               => "1.2.3.4",
                                                             "VM_ID"            => "vm-1000",
                                                             "EXTRAOPTS"        => "option foo \"bar\";option bar baz;",
                 } }

);

#write test data to lab file

write_file( $C->labfile, Data::Dumper->Dump( [ \%LAB_TESTDATA ], [qw(LAB)] ) );

# execute the maintenance function which should remove the selected host above
maintain_labfile( $C, $VM_ALL, $ESX_ALL );
# read out the lab file, which was modified previously
my $LAB_NEW = new LML::Lab( $C->labfile );

# do some checks to verify that maintain_labfile did the job
is_deeply( $LAB_NEW->{HOSTS}{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{MAC},
           $VM_ALL->{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{MAC},
           "should have updated MAC list from VM data" );

is_deeply( $LAB_NEW->{HOSTS}{'4213059e-70c2-6f34-1986-50463d0222f8'}, undef, "should have removed obsolete VM" );

is_deeply( $LAB_NEW->{ESXHOSTS}, $ESX_ALL, "should find ESX hosts in lab file");
done_testing;
