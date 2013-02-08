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

# input parameter, UUID of a VM
my $search_uuid;
if ( param('uuid') ) {
    $search_uuid = param('uuid');
} elsif (@ARGV) {
    $search_uuid = lc( $ARGV[0] );
} else {
    die("Give UUID address as query parameter 'uuid' or as command line parameter\n");
}

my %VM_DATA;
my $status = "200 OK";
my $VM = ReadVmFile;
if ( exists( $VM->{$search_uuid} ) ) {
    %VM_DATA = %{ $VM->{$search_uuid} };

} elsif ( %{$VM} ) {
    $status = "200 No Data for VM $search_uuid found" ;
    %VM_DATA = ( "NO_INFORMATION_AVAILABLE" => "SORRY" );

} else {
    $status = "500 No VM Data Found" ;
    %VM_DATA = ( "FATAL_ERROR" => "NO VM DATA FOUND" );
}


my $json_data = to_json( \%VM_DATA, { utf8 => 0, pretty => 1, allow_blessed => 1 } );

if (Accept("text/json") >= 0.9) {
    print header(-status => $status,-type=>"text/json");
    print $json_data
} else {
    print header(-status => $status,-type=>"text/html");
    print "<html><head><title>Details for $search_uuid</title></head>\n".
        "<body><pre>\n" .
        escapeHTML($json_data)."\n".
        "</pre></body></html>\n";
}

1;
