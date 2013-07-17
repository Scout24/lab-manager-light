use strict;
use warnings;

use File::Slurp;
use Test::More;

use LML::Config;

my $doqrdecoding;
qx(zbarimg --version &>/dev/null);
if ($? > 0) {
    diag "zbarimg not installed -- skipping QR decoding tests";
} else {
    $doqrdecoding = 1;
}

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
write_file("test/temp/vmdata-result.png",$result);
if ($doqrdecoding) {
    like(qx(zbarimg --quiet --raw test/temp/vmdata-result.png),qr/4213038e-9203-3a2b-ce9d-c6dac1f2dbbf/,"QR code should contain UUID of VM");
}
done_testing;
