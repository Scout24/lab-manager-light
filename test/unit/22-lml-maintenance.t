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
my $HOSTS = {
    "testesx01.domain" => {
        "datastores" => [ "testesx01:datastore1" ],
        "hardware"   => {
                        "cpuMhz"        => 2493,
                        "cpuModel"      => "Intel(R) Xeon(R) CPU E5-2640 0 \@ 2.50GHz",
                        "memorySize"    => "274841534464",
                        "model"         => "ProLiant DL360p Gen8",
                        "numCpuCores"   => 12,
                        "numCpuPkgs"    => 2,
                        "numCpuThreads" => 24,
                        "numHBAs"       => 3,
                        "numNics"       => 8,
                        "uuid"          => "12345678-3233-5a43-4a32-34363039574a",
                        "vendor"        => "HP"
        },
        "id"       => "host-1633",
        "name"     => "testesx01.domain",
        "networks" => [
                        "3500_XX_DEV",                "3300_XX_PLAY",
                        "dvSwitch-fe-DVUplinks-1872", "3-internal-only",
                        "3800_XX_STATIC",             "3801_XX_DYN",
                        "dvSwitch-be-DVUplinks-1252", "2500_XX_DEV",
                        "3000_XX_TUV",                "2000_XX_TUV",
                        "2637_XX_devweb",             "dvSwitch2-DVUplinks-1258"
        ],
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
        },
        "quickStats" => {
                          "distributedCpuFairness"    => 300,
                          "distributedMemoryFairness" => 285,
                          "overallCpuUsage"           => 15115,
                          "overallMemoryUsage"        => 213847,
                          "uptime"                    => 11572280
          }
    },
    "testesx01.domain" => {
                                                      "datastores" => [
                                                                        "testesx01:datastore1"
                                                                      ],
                                                      "hardware" => {
                                                                      "cpuMhz" => 2493,
                                                                      "cpuModel" => "Intel(R) Xeon(R) CPU E5-2640 0 \@ 2.50GHz",
                                                                      "memorySize" => "274841534464",
                                                                      "model" => "ProLiant DL360p Gen8",
                                                                      "numCpuCores" => 12,
                                                                      "numCpuPkgs" => 2,
                                                                      "numCpuThreads" => 24,
                                                                      "numHBAs" => 3,
                                                                      "numNics" => 8,
                                                                      "uuid" => "35363636-3233-5a43-4a32-343630395746",
                                                                      "vendor" => "HP"
                                                                    },
                                                      "id" => "host-1598",
                                                      "name" => "testesx01.domain",
                                                      "networks" => [
                                                                      "8-Mgmt-Notfall (741)",
                                                                      "9-Mgmt (741)",
                                                                      "3500_BE_DEV",
                                                                      "3300_BE_PLAY",
                                                                      "1-BE (742)",
                                                                      "dvSwitch-fe-DVUplinks-1872",
                                                                      "3-internal-only",
                                                                      "3800_BE_DEVNIC_STATIC",
                                                                      "3801_BE_DEVNIC_DYN",
                                                                      "dvSwitch-be-DVUplinks-1252",
                                                                      "2-FE (4)",
                                                                      "2500_FE_DEV",
                                                                      "3000_BE_TUV",
                                                                      "2000_FE_TUV",
                                                                      "2637_FE_devweb",
                                                                      "dvSwitch2-DVUplinks-1258"
                                                                    ],
                                                      "product" => {
                                                                     "apiType" => "HostAgent",
                                                                     "apiVersion" => "5.1",
                                                                     "build" => 799733,
                                                                     "fullName" => "VMware ESXi 5.1.0 build-799733",
                                                                     "licenseProductName" => "VMware ESX Server",
                                                                     "licenseProductVersion" => "5.0",
                                                                     "localeBuild" => "000",
                                                                     "localeVersion" => "INTL",
                                                                     "name" => "VMware ESXi",
                                                                     "osType" => "vmnix-x86",
                                                                     "productLineId" => "embeddedEsx",
                                                                     "vendor" => "VMware, Inc.",
                                                                     "version" => "5.1.0"
                                                                   },
                                                      "quickStats" => {
                                                                        "distributedCpuFairness" => 290,
                                                                        "distributedMemoryFairness" => 234,
                                                                        "overallCpuUsage" => 21775,
                                                                        "overallMemoryUsage" => 250991,
                                                                        "uptime" => 11578537
                                                                      }
                                                    },
};

my $NETWORKS = {
    "dvportgroup-1253" => {
                                                 "hosts" => [
                                                              "host-1606",
                                                              "host-1608",
                                                              "host-1598",
                                                              "host-1633",
                                                              "host-1615",
                                                              "host-1637"
                                                            ],
                                                 "id" => "dvportgroup-1253",
                                                 "name" => "dvSwitch2-DVUplinks-1258"
                                               },
                         "dvportgroup-1256" => {
                                                 "hosts" => [
                                                              "host-1606",
                                                              "host-1608",
                                                              "host-1598",
                                                              "host-1633",
                                                              "host-1615",
                                                              "host-1637"
                                                            ],
                                                 "id" => "dvportgroup-1256",
                                                 "name" => "3000_XX_TUV"
                                               },
};

my $DATASTORES = {
    "datastore-1325" => {
                                                 "capacity" => "444797550592",
                                                 "freespace" => "164464951296",
                                                 "hosts" => [
                                                              "host-1633"
                                                            ],
                                                 "id" => "datastore-1325",
                                                 "name" => "testesx01:datastore1",
                                                 "vm" => [
                                                           "vm-1350",
                                                           "vm-1349"
                                                         ]
                                               },
                           "datastore-1599" => {
                                                 "capacity" => "2995202818048",
                                                 "freespace" => "70140297216",
                                                 "hosts" => [
                                                              "host-1598"
                                                            ],
                                                 "id" => "datastore-1599",
                                                 "name" => "testesx02:datastore1",
                                                 "vm" => [
                                                           "vm-461",
                                                           "vm-2205",
                                                           "vm-468",
                                                           "vm-1293",
                                                           "vm-1368",
                                                           "vm-1917",
                                                           "vm-1360",
                                                           "vm-470",
                                                           "vm-1910",
                                                           "vm-1012",
                                                           "vm-1911",
                                                           "vm-2459",
                                                           "vm-2227",
                                                           "vm-1836",
                                                         ]
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

#$isDebug= 1;
write_file( $C->labfile, Data::Dumper->Dump( [ \%LAB_TESTDATA ], [qw(LAB)] ) );

# execute the maintenance function which should remove the selected host above
maintain_labfile( $C, $VM_ALL, $HOSTS, $NETWORKS, $DATASTORES );
# read out the lab file, which was modified previously
my $LAB_NEW = new LML::Lab( $C->labfile );

# do some checks to verify that maintain_labfile did the job
is_deeply( $LAB_NEW->{HOSTS}{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{MAC},
           $VM_ALL->{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{MAC},
           "should have updated MAC list from VM data" );

is_deeply( $LAB_NEW->{HOSTS}{'4213059e-70c2-6f34-1986-50463d0222f8'}, undef, "should have removed obsolete VM" );

is_deeply( $LAB_NEW->{ESXHOSTS}, $HOSTS, "should find ESX hosts in lab file" );
is_deeply( $LAB_NEW->{NETWORKS}, $NETWORKS, "should find ESX hosts in lab file" );
is_deeply( $LAB_NEW->{DATASTORES}, $DATASTORES, "should find ESX hosts in lab file" );
done_testing;
