#!/usr/bin/perl
use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use GD::Barcode::QRcode;
use GD::Image;
use CGI ':standard';
use URI::Escape;

sub generate_image {
        my $data = shift;
        # return data as PNG only if we return data for a single VM, otherwise it would be too much data for the QR code.
        my $im = new GD::Image( 640, 480 );    # always return VGA-sized image
        my $black  = $im->colorAllocate( 0, 0, 0 );

        $im->fill( 0, 0, $black );
        # image height = (17+(Version*4)+8)*ModuleSize (learned from GD::Barcode::QRcode source)
        $im->copy( GD::Barcode::QRcode->new( $data, { Ecc => 'M', Version => 23, ModuleSize => 2 } )->plot,
                   0, 195, 0, 0, 235, 235 );
        return $im->png;
}

my $data;
if ( param("data") )
{
	$data = uri_unescape(param("data"));
}

my $image = generate_image( $data );

print header(
                  -status => ( $image ? 200 : 500 ),
                  -type => "image/png",
                  -Content_length => length($image) );
binmode STDOUT;
print $image;