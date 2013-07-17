use strict;
use warnings;

use Test::More;

use File::Slurp;
#$isDebug = 1;

my $doqrdecoding;
qx(zbarimg --version &>/dev/null);
if ($? > 0) {
    diag "zbarimg not installed -- skipping QR decoding tests";
} else {
    $doqrdecoding = 1;
}

# good case
my ($header,$result) = split("\r\n\r\n",qx(src/lml/backgroundimage.pl data="Hello World"),2);
write_file("test/temp/backgroundimage_good.png",$result);
my $reference_image = read_file("test/data/backgroundimage_good_reference.png");
is($result,$reference_image,"should give same image as good reference image");
if ($doqrdecoding) {
    is(qx(zbarimg --quiet --raw test/temp/backgroundimage_good.png),"Hello World\n","QR code should contain Hello World");
}

# error case
my $long_data = "X X X X X " x 1000;
($header,$result) = split("\r\n\r\n",qx(src/lml/backgroundimage.pl data="$long_data"),2);
write_file("test/temp/backgroundimage_error.png",$result);
$reference_image = read_file("test/data/backgroundimage_error_reference.png");
is($result,$reference_image,"should give same image as error reference image");
if ($doqrdecoding) {
    like(qx(zbarimg --quiet --raw test/temp/backgroundimage_error.png),qr/ERROR/,"QR code should contain ERROR");
}

done_testing();
