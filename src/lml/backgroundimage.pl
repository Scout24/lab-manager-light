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
use LML::Config;
use Carp;

sub generate_image {
        my ($C,$data) = @_;
        carp("Need to provide config as 1st arg") unless (ref($C) eq "LML::Config");
        # return data as PNG only if we return data for a single VM, otherwise it would be too much data for the QR code.
        my $im = new GD::Image( 640, 480 );    # always return VGA-sized image
        my $black  = $im->colorAllocate( 0, 0, 0 );
        my $white = $im->colorAllocate(255,255,255);
        my $warning  = $im->colorAllocate( 255, 36, 0 );

        $im->fill( 0, 0, $black );
        $im->filledRectangle(235,195,640,429,$white);
        # image height = (17+(Version*4)+8)*ModuleSize (learned from GD::Barcode::QRcode source)
        my $qr_image;
        eval {
            $qr_image = GD::Barcode::QRcode->new( $data, { Ecc => 'M', Version => 23, ModuleSize => 2 })->plot;
        };
        if ($@) {
            my $error = "Data: ".substr($data,0,30)."...\n\n".
                ($@ =~ qr(max bits) ? "You provided too much data for \na QR code of ECC=M, Version=23\n\n" : "").
                "GD::Barcode::QRcode ERROR:\n$@";
            # if there was an error plotting the QR data then we put the error message into the QR code and also print it onto
            # the image instead of the logo
            $qr_image = GD::Barcode::QRcode->new( $error , { Ecc => 'M', Version => 23, ModuleSize => 2 })->plot;
            my $y = 200; #start height;
            for my $line (split("\n",$error)) {
                $im->string(GD::Font->Giant, 240,$y, $line,$warning);
                $y+=GD::Font->Giant->height;
            }
        } else {
            # no error, add LML logo and custom pic
            my $logo = new GD::Image( $INC[0] . "/images/LabManagerLightlogo-small.png" );    # logo is 200x75
            $im->copy( $logo, 481, 200 , 0 , 0, 160, 60 );
            my $custompic=$C->get("backgroundimage","customimage");
            $custompic = $INC[0]."/images/".$custompic unless (substr($custompic,0,1) eq "/"); # images that are not fully qualified are assumed to be in lib/images
            if (-r $custompic) {
                my $custompic_image = new GD::Image( $custompic );    # custompic is 400x150
                $im->copy( $custompic_image,239, 279 , 0 , 0, 400, 150 );
            }            
        }
        $im->copy( $qr_image, 0, 195, 0, 0, 235, 235 );
        return $im->png;
}

my $data;
if ( param("data") )
{
	$data = uri_unescape(param("data"));
}

my $image = generate_image( new LML::Config, $data );

print header( -status => 200,
                  -type => "image/png",
                  -Content_length => length($image) );
binmode STDOUT;
print $image;