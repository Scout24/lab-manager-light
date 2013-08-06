#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../../lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::Lab;
use JSON;

use User::pwent;

my $GECOS = {};    # cache for gecos lookups

my $C = new LML::Config();

my $LAB = new LML::Lab( $C->labfile );

my %result = ( 
);

# get full name of userid
sub get_gecos {
    my ($userid) = @_;
    return "" unless ($userid);
    Debug "Looking up $userid";
    if ( not exists $GECOS->{$userid} ) {
        if ( my $pwnam = getpwnam($userid) ) {
            $GECOS->{$userid} = $pwnam->gecos;
        }
        else {
            $GECOS->{$userid} = "Could not lookup user";
        }
        Debug "Caching $userid = " . $GECOS->{$userid};
    }
    return $GECOS->{$userid};
}

sub fill_vm_overview_json {
    my $vm_overview   = [];
    my $display_filter_vm_path = $C->get( "gui",          "display_filter_vm_path" );
    my $contactuser_field      = $C->get( "vsphere",      "contactuserid_field" );
    my $expires_field          = $C->get( "vsphere",      "expires_field" );
    my $screenshot_enabled     = $C->get( "vmscreenshot", "enabled" );

    while ( my ( $uuid, $VM ) = each %{ $LAB->{HOSTS} } ) {
        next unless ( exists $VM->{UUID} );
        my $expires         = "unknown";
        my $contact_user_id = "unknown";
        my $display_vm_path = "<em>(no data available)</em>";
        my $esxhost         = "unknown";
        if ( $expires_field and exists $VM->{CUSTOMFIELDS}->{$expires_field} ) {
            eval { $expires = DateTime::Format::Flexible->parse_datetime( $VM->{CUSTOMFIELDS}->{$expires_field}, european => ( $C->get( "vsphere", "expires_european" ) ? 1 : 0 ) )->ymd(); };
        }
        if ( exists $VM->{PATH} ) {
            $display_vm_path = $VM->{PATH};

            if ($display_filter_vm_path) {
                $display_vm_path =~ s/$display_filter_vm_path/$1/;
            }
        }

        if ( exists $VM->{HOST} ) {
            $esxhost = $VM->{HOST};
        }

        # lowercase contact user id so that SSchapiro and sschapiro will show up as the same and not as two in the drop-down box.
        if ( $contactuser_field and exists( $VM->{CUSTOMFIELDS}->{$contactuser_field} ) ) {
            $contact_user_id = lc( $VM->{CUSTOMFIELDS}->{$contactuser_field} );
        }
        my $screenshot_url = "vmscreenshot.pl?stream=1;uuid=$uuid";

        my %vm_info = ();

        $vm_info{id}               = $VM->{HOSTNAME};
        $vm_info{uuid}             = $uuid;
        $vm_info{fullname}         = $VM->{HOSTNAME} . ( defined( $VM->{DNS_DOMAIN} ) ? "." . $VM->{DNS_DOMAIN} : "" );
        $vm_info{screenshot_enabled}   = $screenshot_url ? "true": "false";
        $vm_info{screenshot_url}   = $screenshot_url if $screenshot_enabled ;
        $vm_info{vm_path}          = $display_vm_path;
        $vm_info{contact_fullname} = get_gecos($contact_user_id);
        $vm_info{contact_id}       = $contact_user_id;
        $vm_info{expires}          = $expires;
        $vm_info{esxhost}          = $esxhost;

        push @{$vm_overview}, \%vm_info;

    }
    return $vm_overview;
}



$result{vm_overview} = fill_vm_overview_json();

print header('application/json');
print encode_json( \%result );
1;
