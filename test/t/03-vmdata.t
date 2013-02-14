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
         "01:02:03:04:6e:4e" : "arc.int"
      },
      "NAME" : "tsthst001",
      "NETWORKING" : [
         {
            "MAC" : "01:02:03:04:6e:4e",
            "NETWORK" : "arc.int"
         }
      ],
      "PATH" : "development/vm/otherpath/tsthst001",
      "UUID" : "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf",
      "VM_ID" : "vm-1000"
   }
}
EOF
my $result = display_vm_data("",1);
is ($result,$vm_json,"all data");
$result = display_vm_data("");
like ($result,qr(.*html.*),"all data as html");
done_testing;
