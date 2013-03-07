#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use JSON;
use LML::Config;
use LML::Common;
use LML::Lab;
use GD::Barcode::QRcode;
use GD::Image;
use Carp;

# uuid is either "" or undef to denote everything
sub display_vm_data {
    my ( $C, $uuid, $content_type ) = @_;
    croak("1st parameter must be LML::Config object") unless ( ref($C) eq "LML::Config" );
    $content_type = "text/html" unless ($content_type);

    my $data;

    # TODO: Read LAB file instead of VM file so that this works right after a new VM has been created!
    my $LAB = new LML::Lab( $C->labfile );

    my $VM;

    if ( not $uuid ) {
        $data = $LAB->{HOSTS};
        $uuid = "all VM";        # use this later for output
    } elsif ( exists( $LAB->{HOSTS}{$uuid} ) ) {
        $data = $VM = $LAB->{HOSTS}{$uuid};
    } else {
        return "";
    }

# canonical makes the output sorted so that the same input always yields the same output. A bit slower but helps the testing...
    my $json_data = to_json( $data, { utf8 => 0, pretty => 1, allow_blessed => 1, canonical => 1 } );

    if ( $content_type eq "application/json" ) {
        return $json_data;
    } elsif ( $VM and $content_type eq "image/png" ) {
        #Debug(Data::Dumper->Dump([$VM]));
       # return data as PNG only if we return data for a single VM, otherwise it would be too much data for the QR code.
        my $im = new GD::Image( 640, 480 );    # always return VGA-sized image
        my $orange = $im->colorAllocate( 224, 102, 102 );
        my $white  = $im->colorAllocate( 255, 255, 255 );

        $im->fill( 0, 0, $white );
        # image height = (17+(Version*4)+8)*ModuleSize (learned from GD::Barcode::QRcode source)
        $im->copy( GD::Barcode::QRcode->new( $json_data, { Ecc => 'M', Version => 23, ModuleSize => 4 } )->plot,
                   0, 0, 0, 0, 480, 480 );
        my $y = 70;
        # NOTE: With %{..} we dereference the hashref and use the fact that in perl a hash is also an array!
        foreach (
                  "Name:", $VM->{HOSTNAME},
                  "",      exists $VM->{MAC} ? ( "Network:", %{ $VM->{MAC} } ) : (),
                  "",      exists $VM->{CUSTOMFIELDS} ? ( "Custom Fields:", %{ $VM->{CUSTOMFIELDS} } ) : (),
                  "",      exists $VM->{VM_ID} ? ( "Mo-Ref:", $VM->{VM_ID} ) : (),
                  "",      exists $VM->{HOST} ? ( "Host:", $VM->{HOST} ) : (),
          )
        {
            #Debug("Writing $_");
            $im->string( GD::Font->Giant, 480, $y, $_, $orange );
            $y += GD::Font->Giant->height;
        }
        my $logo = new GD::Image( $INC[0] . "/images/LabManagerLightlogo-small.png" );    # logo is 200x75
        $im->copy( $logo, 481, 0, 0, 0, 160, 60 );

        return $im->png;
    } else {
        # html is default and fall-back
        return
            "<html><head><title>Details for $uuid</title></head>\n"
          . "<body><pre>\n"
          . escapeHTML($json_data) . "\n"
          . "</pre></body></html>\n";
    }
}

# main() code when running as stand-alone program
unless (caller) {
    my $C = new LML::Config();

    my $search_uuid;
    my $content_type;
    my $suffix = "";
    # for which VM to display data
    if ( param('uuid') ) {
        # parameter from request parameter
        $search_uuid = param('uuid');
    } elsif ( path_info() ) {
        # or from path_info
        ( $search_uuid, $suffix ) = path_info() =~ m#/([^.]+)\.?(.*)#;
        $suffix = lc($suffix);
    } else {
        # or default to nothing
        $search_uuid = "";    # use this to denote everything
    }
    $search_uuid = lc($search_uuid);

    # how to display the data
    if ( param("type") ) {
        # from request parameter
        $content_type = lc( param("type") );
    } elsif ( Accept("application/json") >= 0.9 or Accept("text/json") >= 0.9 or $suffix eq "json" ) {
        # set content-type from Accept header or from path suffix
        $content_type = "application/json";
    } elsif ( Accept("image/png") >= 0.9 or $suffix eq "png" ) {
        # set content-type from Accept header or from path suffix
        $content_type = "image/png";
    } elsif ( $suffix eq "pxelinux" ) {
        # we use pxelinux as fake content-type to say that we should produce something that pxelinux understands
        $content_type = "pxelinux";
    } else {
        # or default is HTML
        $content_type = "text/html";
    }

    my $result;
    if ( $content_type eq "pxelinux" and $C->get( "pxelinux", "qrdata_template" ) ) {
        # pxelinux content-type actually contains other content
        $content_type = "text/plain";
        $result = join( "\n", @{ $C->get( "pxelinux", "qrdata_template" ) } );
        my $url = url() . "/" . $search_uuid . ".png";    # write image as query path
        $result =~ s/URL/$url/;
    } else {
        $result = display_vm_data( $C, $search_uuid, $content_type );
    }
    print header(
                  -status => ( $result ? 200 : 404 ),
                  -type => $content_type,
                  -Content_length => length($result) );
    print $result;
}
