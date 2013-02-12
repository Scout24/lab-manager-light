#!/usr/bin/perl
#
#
# unsetForceBoot.pl	Lab Manager Light unset Force Boot
#
# Authors:
# GSS		Schlomo Schapiro <lml@schlomo.schapiro.org>
#
# Copyright:	Schlomo Schapiro, Immobilien Scout GmbH
# License:	GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full text
#
#

use strict;
use warnings;

# Place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::Subversion;
use LML::VMware;
use LML::DHCP;

LoadConfig();

# Connect to vSphere
connect_vi();

# Input parameter, UUID of a VM
my $search_uuid = param('uuid') ? lc( param('uuid') ) : lc( $ARGV[0] );

die "No forceboot_field parameter set in [vsphere] section\n" unless ( Config( "vsphere", "forceboot_field" ) );

if ($search_uuid) {
    print header('text/plain');

    # Get dump of single VM from vSphere
    my %VM = get_vm_data($search_uuid);
    my $forceboot_target_field = Config( "vsphere", "forceboot_target_field" );

    # The new variant is to use the forceboot field as trigger, set a coherent value
    if ( $forceboot_target_field and $VM{$search_uuid}{CUSTOMFIELDS}{$forceboot_target_field} ) {
        setVmCustomValueU( $search_uuid, $CONFIG{vsphere}{forceboot_field}, "OFF" );

    }

    # The old variant is to clear the forceboot field
    else {
        setVmCustomValueU( $search_uuid, $CONFIG{vsphere}{forceboot_field}, "" );
    }
} else {
    print header( -status => 404, -type => 'text/plain' );
    print "Give UUID address as query parameter 'uuid' or as command line parameter\n";
}
