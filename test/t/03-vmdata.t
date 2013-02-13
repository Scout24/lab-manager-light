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
   "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" : {
      "NETWORKING" : [
         {
            "NETWORK" : "arc.int",
            "MAC" : "01:02:03:04:6e:4e"
         }
      ],
      "NAME" : "tsthst001",
      "EXTRAOPTIONS" : {
         "bios.bootDeviceClasses" : "allow:net"
      },
      "MO_REF" : null,
      "MAC" : {
         "01:02:03:04:6e:4e" : "arc.int"
      },
      "PATH" : "development/vm/otherpath/tsthst001",
      "CUSTOMFIELDS" : {
         "Contact User ID" : "User2",
         "Force Boot" : "",
         "Expires" : "31.01.2013"
      },
      "UUID" : "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"
   },
   "42130272-a509-8010-6e85-4e01cb1b7284" : {
      "NETWORKING" : [
         {
            "NETWORK" : "arc.int",
            "MAC" : "01:02:03:04:00:15"
         }
      ],
      "NAME" : "lochst001",
      "EXTRAOPTIONS" : {
         "bios.bootDeviceClasses" : "allow:net"
      },
      "MO_REF" : null,
      "MAC" : {
         "01:02:03:04:00:15" : "arc.int"
      },
      "PATH" : "development/vm/path/lochst001",
      "CUSTOMFIELDS" : {
         "Contact User ID" : "User1",
         "Expires" : "31.12.2013"
      },
      "UUID" : "42130272-a509-8010-6e85-4e01cb1b7284"
   }
}
EOF
my $result = display_vm_data("",1);
is ($result,$vm_json,"all data");
$result = display_vm_data("");
like ($result,qr(.*html.*),"all data as html");
done_testing;
