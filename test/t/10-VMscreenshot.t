use strict;
use warnings;

use File::Slurp;
use Test::More;
use Test::Warn;
use Test::Exception;
use Text::Diff;
use CGI;
use Cwd;
use Data::Dumper;

use LML::Config;

BEGIN {
    use_ok "LML::VMscreenshot";
}

my @conffiles = ( "src/lml/default.conf", "test/data/test.conf" );
dies_ok { new LML::VMscreenshot } "Should die with parameter error";
dies_ok { new LML::VMscreenshot( new LML::Config(@conffiles) ) } "Should die with parameter error";
is( new LML::VMscreenshot( new LML::Config(@conffiles), "abcd" ),
    undef, "New object with invalid uuid should be undef" );

my $C = new LML::Config(@conffiles);
# test/data/screen should be a PNG file
$ENV{VI_SERVER} = "file://" . cwd() . "/test/data";
my $screenshot = new_ok( "LML::VMscreenshot" => [ $C, "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" ],
                         "Should return object" );
my $png_re = qr(\211PNG\r\n\32\n\0\0\0\rIHDR.*\202)s;
like( $screenshot->png, $png_re, "Should return something like png" );
like( $screenshot->render( new CGI, -1 ),
      qr(Expires:.*Date.*Content-length: 273\r\nContent-Type: image/png; charset=ISO-8859-1\r\n\r\n${png_re})s,
      "should return HTTP response with PNG like in it" );
is( $screenshot->render( new CGI, 100000 ),
    undef, "render should return undef if requested page is larger that push_max" );
like(
    $screenshot->render( new CGI, 25 ),
qr(Expires:.*Date.*Content-length: 273\r\nLml-page: last\r\nContent-Type: image/png; charset=ISO-8859-1\r\n\r\n${png_re})s,
    "should return  last HTTP response with png in it"
);
done_testing();
