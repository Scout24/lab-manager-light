use strict;
use warnings;

use Test::More;
use File::Slurp;
#$isDebug = 1;

$ENV{DOCUMENT_ROOT} = "test/data/";
my $testfile = "proxytest.txt";

# good case
my ( $header, $result ) = split( "\r\n\r\n", qx(src/lml/pxelinux-proxy.pl filename=$testfile token=true othertoken1=false), 2 );
is(
    $result,
    "test true is true and not false,
but false might still be true, but can't be !!!NO_TOKEN_invalid_token!!!

config blah.pxelinux?token=true;othertoken1=false or blub.pxelinux?token=true;othertoken1=false

menu junk

config foo.pxelinux?token=true;othertoken1=false
",
    "tokens correctly replaced"
);

# error case
( $header, $result ) = split( "\r\n\r\n", qx(src/lml/pxelinux-proxy.pl filename=no-such-file.txt), 2 );
is(
    $header,
    "Status: 404 File not found\r
Content-Type: text/html; charset=ISO-8859-1",
    "Correct header for error"
);

# error case of relative filename
( $header, $result ) = split( "\r\n\r\n", qx(src/lml/pxelinux-proxy.pl filename=../../etc/passwd), 2 );
is(
    $header,
    "Status: 500 Relative filename forbidden\r
Content-Type: text/html; charset=ISO-8859-1",
    "Correct header for hacking attempt"
);

done_testing();
