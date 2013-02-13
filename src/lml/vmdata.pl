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

# uuid is either "" or undef to denote everything
sub display_vm_data($;$) {
    my $uuid = shift;
    my $as_json = shift;
    
    my %VM_DATA;

    my $VM = ReadVmFile();
    if ( $uuid eq "" or $uuid eq undef ) {
        %VM_DATA = %{$VM};
    } elsif ( exists( $VM->{$uuid} ) ) {
        %VM_DATA = %{ $VM->{$uuid} };
    } else {
        return undef;
    } 
    
    my $json_data = to_json( \%VM_DATA, { utf8 => 0, pretty => 1, allow_blessed => 1 } );

    if ( $as_json) {
        return $json_data;
    } else {
        return "<html><head><title>Details for $uuid</title></head>\n" . "<body><pre>\n" . escapeHTML($json_data) . "\n" . "</pre></body></html>\n";
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
    my $as_json = Accept("text/json") >= 0.9;

    my $result = display_vm_data( $search_uuid, $as_json );
    print header( -status => ( $result ? 200 : 500 ),
                  -type => "text/" . ( $as_json ? "json" : "html" ) );
    print $result;
    exit( $result ? 0 : 1 ); # report status as exit code
}
