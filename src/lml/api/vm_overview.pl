#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::Lab;
use DateTime::Format::Flexible;
use JSON;
use File::Slurp;

use User::pwent;

my $C = new LML::Config();


my %result = ();

sub fill_vm_overview_json {
    my ($LAB) = @_; 
    my $vm_overview            = [];
    my $display_filter_vm_path = $C->get( "gui", "display_filter_vm_path" );
    my $contactuser_field      = $C->get( "vsphere", "contactuserid_field" );
    my $expires_field          = $C->get( "vsphere", "expires_field" );
    my $screenshot_enabled     = $C->get( "vmscreenshot", "enabled" );
    my $force_boot_field       = $C->get( "vsphere", "forceboot_field" );
    my $extra_link_text        = $C->get( "gui", "extra_link_text" );
    my $expires_european       = $C->get( "vsphere", "expires_european" );
    my $expires_maximum        = $C->get( "vsphere", "expires_maximum" );
    while ( my ( $uuid, $VM ) = each %{ $LAB->{HOSTS} } ) {
        next unless ( exists $VM->{UUID} );
        my $expires         = "unknown";
        my $expires_bad     = "false";
        my $contact_user_id = "unknown";
        my $display_vm_path = "<em>(no data available)</em>";
        my $esxhost         = "unknown";
        if ( $expires_field and exists $VM->{CUSTOMFIELDS}->{$expires_field} ) {
            eval {
                my $expires_dt = DateTime::Format::Flexible->parse_datetime( $VM->{CUSTOMFIELDS}->{$expires_field},
                                                                       european => ( $expires_european ? 1 : 0 ) );
                $expires = $expires_dt->ymd();
                if ( DateTime->compare( DateTime->now(), $expires_dt ) > 0 ) {
                    $expires     = "$expires already expired";
                    $expires_bad = "true";
                }
                elsif ( DateTime->compare( $expires_dt, DateTime->now()->add( days => $expires_maximum ) ) >= 0 ) {
                    $expires     = "$expires expires in more than $expires_maximum days";
                    $expires_bad = "true";
                }

            };
            # ignore errors in date decoding
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

        my $show_extra_link =
          (     defined $VM->{CLIENT_IP}
            and defined $VM->{CUSTOMFIELDS}->{$force_boot_field}
            and $VM->{CUSTOMFIELDS}->{$force_boot_field} !~ /^(off||0|false)$/i );
        $vm_info{id}                 = $VM->{HOSTNAME};
        $vm_info{uuid}               = $uuid;
        $vm_info{fullname}           = $VM->{HOSTNAME} . ( defined( $VM->{DNS_DOMAIN} ) ? "." . $VM->{DNS_DOMAIN} : "" );
        $vm_info{screenshot_enabled} = $screenshot_url ? "true" : "false";
        $vm_info{screenshot_url}     = $screenshot_url if $screenshot_enabled;
        $vm_info{vm_path}            = $display_vm_path;
        $vm_info{contact_id}         = $contact_user_id;
        $vm_info{expires}            = $expires;
        $vm_info{date_bad}           = $expires_bad; # field should not contain expires to allow searching for expires
        $vm_info{esxhost}            = $esxhost;
        # show extra link if we have a client IP and force boot is currently set on.
        # TODO reuse force boot detection logic from VMPolicy instead of copying it here.
        # TODO understand if link text should be customized for each VM
        $vm_info{extra_link_text} = $show_extra_link ? $extra_link_text : "";

        $vm_info{extra_link_url} = $show_extra_link ? "http://$VM->{CLIENT_IP}" : 0;
        $vm_info{extra_link_enabled} = $show_extra_link ? "true" : "false";
        push @{$vm_overview}, \%vm_info;

    }
    return $vm_overview;
}

print header('application/json');

my $mock_file = $ENV{HOME}."/.lml-vm_overview.json";
if (-s $mock_file) {
    Debug("Sending mock file ".$mock_file);
    print read_file($mock_file);
} else {
    my $LAB = new LML::Lab( $C->labfile );
    $result{vm_overview} = fill_vm_overview_json($LAB);
    print encode_json( \%result );
}
1;
