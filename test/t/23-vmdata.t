use strict;
use warnings;

use File::Slurp;
use Test::More;
use Test::Warn;
use Text::Diff;
use LML::Config;
use LML::Common;
BEGIN {
    require_ok "src/lml/vmdata.pl";
}

my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

unshift(@INC,"src/lml/lib"); # we find our images from this

my $result = display_vm_data($C,"","text/json");
chomp($result);
# would be better to make a full comparison, but the output order of the hash keys is undeterminable
like ($result,qr(.*development/vm/otherpath/tsthst001.*)sx,"all data");
$result = display_vm_data($C,"");
like ($result,qr(.*html.*),"all data as html");
#$isDebug=1;
$result = display_vm_data($C,"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf","image/png");
like ($result,qr(\211PNG\r\n\32\n\0\0\0\rIHDR.*\202)s,"single VM as png");
done_testing;
