use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok "LML::Common";
}

# test basic config subsystem
LoadConfig( "src/lml/default.conf", "test/data/test.conf" );
isa_ok( \%CONFIG, "HASH", "CONFIG hash" );
is( Config( "lml", "datadir" ), "test/temp", "test datadir set to test/temp" );

# test vm.conf loading
my %VM_TESTDATA = (
                    "42130272-a509-8010-6e85-4e01cb1b7284" => {
                                                                "CUSTOMFIELDS" => {
                                                                                    "Contact User ID" => "User1",
                                                                                    "Expires"         => "31.12.2013"
                                                                },
                                                                "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
                                                                "MAC"          => { "01:02:03:04:00:15"      => "arc.int" },
                                                                "NAME"       => "lochst001",
                                                                "NETWORKING" => [
                                                                                  {
                                                                                    "MAC"     => "01:02:03:04:00:15",
                                                                                    "NETWORK" => "arc.int"
                                                                                  }
                                                                ],
                                                                "PATH" => "development/vm/path/lochst001",
                                                                "VM_ID" => "vm-0500",
                                                                "UUID" => "42130272-a509-8010-6e85-4e01cb1b7284"
                    },
                    "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
                                                                "CUSTOMFIELDS" => {
                                                                                    "Contact User ID" => "User2",
                                                                                    "Expires"         => "31.01.2013",
                                                                                    "Force Boot"      => ""
                                                                },
                                                                "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
                                                                "MAC"          => { "01:02:03:04:6e:4e"      => "arc.int",
                                                                                    "01:02:03:04:9e:9e" => "foo"
                                                                 },
                                                                "NAME"       => "tsthst001",
                                                                "NETWORKING" => [
                                                                                  {
                                                                                    "MAC"     => "01:02:03:04:6e:4e",
                                                                                    "NETWORK" => "arc.int"
                                                                                  },
                                                                                  {
                                                                                    "MAC"     => "01:02:03:04:9e:9e",
                                                                                    "NETWORK" => "foo"
                                                                                  }
                                                                ],
                                                                "PATH" => "development/vm/otherpath/tsthst001",
                                                                "VM_ID" => "vm-1000",
                                                                "UUID" => "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"
                    },
                    "4213038e-9203-3a2b-ce9d-123456789abc" => {
                                                                "CUSTOMFIELDS" => {
                                                                                    "Contact User ID" => "User3",
                                                                                    "Expires"         => "31.01.2010",
                                                                                    "Force Boot"      => "garbage",
                                                                                    "Force Boot Target" => "server"
                                                                },
                                                                "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
                                                                "MAC"          => { "01:02:03:04:6e:5c"      => "arc.int" },
                                                                "NAME"       => "tsthst099",
                                                                "NETWORKING" => [
                                                                                  {
                                                                                    "MAC"     => "01:02:03:04:6e:5c",
                                                                                    "NETWORK" => "arc.int"
                                                                                  }
                                                                ],
                                                                "PATH" => "development/vm/otherpath/tsthst099",
                                                                "VM_ID" => "vm-2000",
                                                                "UUID" => "4213038e-9203-3a2b-ce9d-123456789abc"
                    },
                    "4213c435-a176-a533-e07e-38644cf43390" => {
                                                                "CUSTOMFIELDS" => {
                                                                                   "Contact User ID" => "unrelated1",
                                                                                   "Expires" => "01.01.2015"
                                                                                  },
                                                                "MAC" => {
                                                                           "01:02:03:04:2e:73" => "vlan_902"
                                                                         },
                                                                "NAME" => "Some VM123",
                                                                "NETWORKING" => [
                                                                                  {
                                                                                    "MAC" => "01:02:03:04:2e:73",
                                                                                    "NETWORK" => "vlan_123"
                                                                                  }
                                                                                ],
                                                                "PATH" => "development/vm/Unrelated/VMPath/Web-Java/Some VM123",
                                                                "UUID" => "4213c435-a176-a533-e07e-38644cf43390",
                                                                "VM_ID" => "vm-9876"
                                                              }
                    
);

# dump %VM to file
open( VM_CONF, ">$CONFIG{lml}{datadir}/vm.conf" ) || die "Could not open '$CONFIG{lml}{datadir}/vm.conf' for writing";
flock( VM_CONF, 2 ) || die;
print VM_CONF "# " . __FILE__ . " " . POSIX::strftime( "%Y-%m-%d %H:%M:%S\n", localtime() ) . "\n";
print VM_CONF Data::Dumper->Dump( [ \%VM_TESTDATA ], [qw(VM)] );
close(VM_CONF);

# now read the data back from file and compare it with the original data
my %VM = %{ ReadVmFile() };
is_deeply( \%VM, \%VM_TESTDATA, "VM loaded correctly" );

# test lab.conf loading
my %LAB_TESTDATA = (
    "DHCP"  => {},
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
                                                    "EXTRAOPTS"        => "option foo \"bar\";option bar baz;",
        }
      }

);
open( LAB_CONF, ">", "$CONFIG{lml}{datadir}/lab.conf" ) || die "Could not open $CONFIG{lml}{datadir}/lab.conf";
print LAB_CONF "# " . __FILE__ . " " . POSIX::strftime( "%Y-%m-%d %H:%M:%S\n", localtime() ) . "\n";
print LAB_CONF Data::Dumper->Dump( [ \%LAB_TESTDATA ], [qw(LAB)] );
close(LAB_CONF);
my %LAB = %{ ReadLabFile() };
is_deeply( \%LAB_TESTDATA, \%LAB, "LAB loaded correctly" );
done_testing;
