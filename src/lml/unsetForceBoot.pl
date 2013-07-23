#!/usr/bin/perl

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::VMmodify;

# load the configuration. Is provided by %CONFIG then
my $C = new LML::Config;

# connect to vSphere
connect_vi();

# input parameter, UUID of a VM
my $search_uuid = param('uuid') ? lc( param('uuid') ) : "";

if ($search_uuid) {
    # Deactivate forceboot
    my $result =
      remove_forceboot( $C, $search_uuid ) ? "200 Successfully removed forceboot" : "400 Could not remove force boot";
    print header(
                  -status => $result,
                  -type   => "text/plain"
    ) . $result . "\n";
} else {
    print header( -status => 404, -type => 'text/plain' );
    print "Give UUID address as query parameter 'uuid'\n";
}
