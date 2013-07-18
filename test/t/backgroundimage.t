use strict;
use warnings;

use Test::More;
use JSON;
use File::Slurp;
#$isDebug = 1;


# good case
$ENV{HOME}="test/data";

my ($header,$result) = split("\r\n\r\n",qx(src/lml/backgroundimage.pl data="Hello World"),2);
write_file("test/temp/backgroundimage_good.png",$result);
is(qx(zbarimg --quiet --raw test/temp/backgroundimage_good.png),"Hello World\n","QR code should contain Hello World");

# good case with n and e parameters

($header,$result) = split("\r\n\r\n",qx(src/lml/backgroundimage.pl 'n=foobar12;e=There was an error;e=Another error happened;e=And this is just a test'),2);
write_file("test/temp/backgroundimage_good_n_e.png",$result);
is_deeply(from_json(qx(zbarimg --quiet --raw test/temp/backgroundimage_good_n_e.png)),{
   "ERRORCOUNT" => 3,
   "ERRORS" => [
      "There was an error",
      "Another error happened",
      "And this is just a test"
   ],
   "NAME" => "foobar12"
},"QR code should contain Hello World");


# error case
my $long_data = "X X X X X " x 1000;
($header,$result) = split("\r\n\r\n",qx(src/lml/backgroundimage.pl data="$long_data"),2);
write_file("test/temp/backgroundimage_error.png",$result);
like(qx(zbarimg --quiet --raw test/temp/backgroundimage_error.png),qr/ERROR/,"QR code should contain ERROR");

done_testing();
