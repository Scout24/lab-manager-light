#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use JSON;
use LML::Common;
use GD::Barcode::QRcode;

# uuid is either "" or undef to denote everything
sub display_vm_data {
    my ( $uuid, $content_type ) = @_;
    $content_type = "text/html" unless ($content_type);

    my %VM_DATA;

    my $VM = ReadVmFile();
    if ( not $uuid ) {
        %VM_DATA = %{$VM};
    } elsif ( exists( $VM->{$uuid} ) ) {
        %VM_DATA = %{ $VM->{$uuid} };
    } else {
        return undef;
    }

# canonical makes the output sorted so that the same input always yields the same output. A bit slower but helps the testing...
    my $json_data = to_json( \%VM_DATA, { utf8 => 0, pretty => 1, allow_blessed => 1, canonical => 1 } );

    if ( $content_type eq "text/json" ) {
        return $json_data;
    } elsif ( $content_type eq "image/png" ) {
        return GD::Barcode::QRcode->new( $json_data, { Ecc => 'Q', Version => 23, ModuleSize => 4 } )->plot->png;
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
    LoadConfig();

    # input parameter, UUID of a VM
    my $search_uuid;
    if ( param('uuid') ) {
        $search_uuid = param('uuid');
    } elsif (@ARGV) {
        $search_uuid = lc( $ARGV[0] );
    } else {
        $search_uuid = undef;    # use this to denote everything
    }
    my $content_type;
    if ( param("type") ) {
        $content_type = lc( param("type") );
    } elsif ( Accept("text/json") >= 0.9 ) {
        $content_type = "text/json";
    } elsif ( Accept("image/png") >= 0.9 ) {
        $content_type = "image/png";
    } else {
        $content_type = "text/html";
    }

    my $result;
    if ( user_agent("PXE") or param("pxelinux")) {
        $content_type = "text/plain";
        $result = join("\n",@{$CONFIG{"pxelinux"}{"qrdata_template"}});
        my $url = url()."?uuid=$search_uuid;type=image/png";
        $result =~ s/URL/$url/;
    } else {
        $result = display_vm_data( $search_uuid, $content_type );
    }
    print header(
                  -status => ( $result ? 200 : 500 ),
                  -type => $content_type,
                  -Content_length => length($result) );
    print $result;
    exit( $result ? 0 : 1 );    # report status as exit code
}
