#!/usr/bin/perl


use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::VMware;
use LML::VMmodify;

# load the configuration. Is provided by %CONFIG then
LoadConfig();

# connect to vSphere
connect_vi();

# input parameter, UUID of a VM
my $search_uuid = param('uuid') ? lc( param('uuid') ) : ( scalar(@ARGV) ? lc( $ARGV[0] ) : "" );

die "No forceboot_field parameter set in [vsphere] section\n" unless ( Config( "vsphere", "forceboot_field" ) );

if ($search_uuid) {
    print header('text/plain');

    # Deactivate forceboot
    remove_forceboot($search_uuid);

} else {
    print header( -status => 404, -type => 'text/plain' );
    print "Give UUID address as query parameter 'uuid' or as command line parameter\n";
}

Util::disconnect();
