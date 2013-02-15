use strict;
use warnings;

use File::Slurp;
use Test::More;
use Test::Warn;
use Text::Diff;
use LML::Common;
BEGIN {
    require_ok "src/lml/vmdata.pl";
}

LoadConfig( "src/lml/default.conf", "test/data/test.conf" );

# NOTE: Indentation with 3 spaces! Use print STDERR $result to get a fresh copy of the display_vm_data result.
my $vm_json=<<EOF;
{
   "42130272-a509-8010-6e85-4e01cb1b7284" : {
      "CUSTOMFIELDS" : {
         "Contact User ID" : "User1",
         "Expires" : "31.12.2013"
      },
      "EXTRAOPTIONS" : {
         "bios.bootDeviceClasses" : "allow:net"
      },
      "MAC" : {
         "01:02:03:04:00:15" : "arc.int"
      },
      "NAME" : "lochst001",
      "NETWORKING" : [
         {
            "MAC" : "01:02:03:04:00:15",
            "NETWORK" : "arc.int"
         }
      ],
      "PATH" : "development/vm/path/lochst001",
      "UUID" : "42130272-a509-8010-6e85-4e01cb1b7284",
      "VM_ID" : "vm-0500"
   },
   "4213038e-9203-3a2b-ce9d-123456789abc" : {
      "CUSTOMFIELDS" : {
         "Contact User ID" : "User3",
         "Expires" : "31.01.2010",
         "Force Boot" : "garbage",
         "Force Boot Target" : "server"
      },
      "EXTRAOPTIONS" : {
         "bios.bootDeviceClasses" : "allow:net"
      },
      "MAC" : {
         "01:02:03:04:6e:5c" : "arc.int"
      },
      "NAME" : "tsthst099",
      "NETWORKING" : [
         {
            "MAC" : "01:02:03:04:6e:5c",
            "NETWORK" : "arc.int"
         }
      ],
      "PATH" : "development/vm/otherpath/tsthst099",
      "UUID" : "4213038e-9203-3a2b-ce9d-123456789abc",
      "VM_ID" : "vm-2000"
   },
   "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" : {
      "CUSTOMFIELDS" : {
         "Contact User ID" : "User2",
         "Expires" : "31.01.2013",
         "Force Boot" : ""
      },
      "EXTRAOPTIONS" : {
         "bios.bootDeviceClasses" : "allow:net"
      },
      "MAC" : {
         "01:02:03:04:6e:4e" : "arc.int",
         "01:02:03:04:9e:9e" : "foo"
      },
      "NAME" : "tsthst001",
      "NETWORKING" : [
         {
            "MAC" : "01:02:03:04:6e:4e",
            "NETWORK" : "arc.int"
         },
         {
            "MAC" : "01:02:03:04:9e:9e",
            "NETWORK" : "foo"
         }
      ],
      "PATH" : "development/vm/otherpath/tsthst001",
      "UUID" : "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf",
      "VM_ID" : "vm-1000"
   },
   "4213c435-a176-a533-e07e-38644cf43390" : {
      "CUSTOMFIELDS" : {
         "Contact User ID" : "unrelated1",
         "Expires" : "01.01.2015"
      },
      "MAC" : {
         "01:02:03:04:2e:73" : "vlan_902"
      },
      "NAME" : "SomeVM123",
      "NETWORKING" : [
         {
            "MAC" : "01:02:03:04:2e:73",
            "NETWORK" : "vlan_123"
         }
      ],
      "PATH" : "development/vm/Unrelated/VMPath/Web-Java/SomeVM123",
      "UUID" : "4213c435-a176-a533-e07e-38644cf43390",
      "VM_ID" : "vm-9876"
   }
}
EOF
my $result = display_vm_data("",1);
is ($result,$vm_json,"all data");
$result = display_vm_data("");
like ($result,qr(.*html.*),"all data as html");
done_testing;
