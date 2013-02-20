#!/usr/bin/perl
#
#
# pxelinux.pl	Lab Manager Light pxelinux interface
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

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::VMware;
use LML::VM;
use LML::Config;
use LML::VMpolicy;
use LML::DHCP;
use LML::Result;
use Data::Dumper;

my $C = new LML::Config();    # implicitly also fills %LML::Common::CONFIG

# our URL base from REQUEST_URI
our $base_url = url();
$base_url =~ s/\/[^\/]+$//;    # cheap dirname()

# install die handler to report fatal errors
$SIG{__DIE__} = sub {
    die @_ if $^S;                     # see http://perldoc.perl.org/functions/die.html at the end
    return unless ( Config( "lml", "showfatalerrors" ) and Config( "pxelinux", "fatalerror_template" ) );
    my $message = shift;
    chomp($message);                   # remove trailing newlines
    $message =~ s/\n/; /;              # turn message into single line
    print header( -status => '200 Fatal Error', -type => 'text/plain' );
    my $body = join( "\n", @{ Config( "pxelinux", "fatalerror_template" ) } ) . "\n";
    $body =~ s/MESSAGE/$message/;
    print $body;
};

# input parameter, UUID of a VM
my $search_uuid;
if ( param('uuid') ) {
    $search_uuid = param('uuid');
} elsif (@ARGV) {
    $search_uuid = lc( $ARGV[0] );
} else {
    die("Give UUID address as query parameter 'uuid' or as command line parameter\n");
}

my $vm_name = "";
my @error   = ();

# connect to vSphere
connect_vi();

# read history to detect renamed VMs and to be able to update the DHCP
my $LAB = ReadLabFile;

# prepare some configuration variables
my @vsphere_networks = ();                                       # list of network names for which LML is responsible.
my $config_vsphere_networks = Config( "vsphere", "networks" );
if ($config_vsphere_networks) {
    if ( ref($config_vsphere_networks) eq "ARRAY" ) {
        @vsphere_networks = @{$config_vsphere_networks};
    } else {
        @vsphere_networks = ($config_vsphere_networks);
    }
}

my $has_changed = 0;

# keep force boot info for later
my $pxelinux_config_url;
my $bootinfo;

my $VM = new LML::VM($search_uuid);
my $result = new LML::Result( $C, url() );

# if there are VMs and if we find the VM we are looking for:
if ( %{$VM} and $VM->uuid and $search_uuid eq $VM->uuid ) {
    $vm_name = $VM->name;

    # check if we should handle this VM
    my @vm_lab_macs = $VM->get_macs_for_networks(@vsphere_networks);
    if ( !@vm_lab_macs ) {
        print header( -status => "404 VM does not match LML networks and is out of scope", -type => 'text/plain' );
        exit 0;
    }

    # modify VM if configured and current setting not as it should be (because the reconfigure VM task takes time)
    if ( $C->get( "modifyvm", "forcenetboot" ) and not $VM->forcenetboot ) {
        $VM->activate_forcenetboot;
    }

    my $Policy = new LML::VMpolicy( $C, $VM );

    $result->add_error(
        $Policy->validate_vm_name,
        $Policy->validate_hostrules_pattern,
        $Policy->validate_dns_zones,
        $Policy->validate_contact_user,
        $Policy->validate_expiry,
        $Policy->validate_vm_dns_name($LAB),
    );

    $Policy->handle_forceboot($result);
    @error = $result->{errors};
    $pxelinux_config_url = "../".$result->{redirect_target};
    $bootinfo = $result->{bootinfo};
    #Debug(Data::Dumper->Dump([\@error],["error"]));


    # up till here we have only checks that verify the VM.
    # in case of errors stop processing so that we do not create host records anywhere as long
    # as some conditions are unmet.

    # we only modify something if there are no errors
    if ( not $result->get_errors ) {

        # add lastseen info to host
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN}         = time;
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN_DISPLAY} = POSIX::strftime( "%a %b %e %H:%M:%S %Y", localtime );

        # create HOSTS record for DHCP if it has changed (name or networking)
        # ~~ compares array since perl 5.10!!
        #
        # NOTE: This should be after all other pieces of code that compare with the old host name !!!
        if (    not( exists( $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} ) and exists( $LAB->{HOSTS}->{$search_uuid}->{MACS} ) )
             or not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}
             or not @vm_lab_macs ~~ @{ $LAB->{HOSTS}->{$search_uuid}->{MACS} } )
        {
            $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} = $vm_name;
            $LAB->{HOSTS}->{$search_uuid}->{MACS}     = \@vm_lab_macs;
            $has_changed                              = 1;
        }
    }    # no errors in @error

}    # if have $VM

# disconnect from VI
Util::disconnect();

# housekeeping is in tools/lml-maintenance.pl. This script has only the scope of a single VM.

# write dhcp-hosts.conf if it is configured and if we have host entries to write
if ($has_changed) {
    push( @error, UpdateDHCP($LAB) );
}

if ( scalar(@error) ) {

    # have some errors
    print header( -status => "200 Errors: " . join( ", ", @error ), -type => 'text/plain' );
    print join( "\n", @{ Config( "pxelinux", "error_main" ) } ) . "\n";    # multiline values come as array
    print "menu title " . Config( "pxelinux", "error_title" ) . " " . $vm_name . "\n";
    my $c = 1;
    foreach my $e (@error) {
        $e =~ s/\^/^^/g;                                                   # pxelinux menu uses ^ to mark keyboard shortcuts. ^^ comes out as plain ^
        print <<EOF;
label l$c
        menu label $c. $e
EOF
        print join( "\n", @{ Config( "pxelinux", "error_item" ) } ) . "\n";
        $c++;
    }

    # if the VM is found and all is fine then redirect to default PXE configuration
} elsif ($vm_name) {

    # dump $LAB to file only if all is fine. This makes sure that LML stays with the old view of the lab for some kind of
    # hard to catch errors.
    my $labfile = Config( "lml", "datadir" );
    open( LAB_CONF, ">", "$labfile/lab.conf" ) || die "Could not open '$labfile' for writing\n";
    flock( LAB_CONF, 2 ) || die;
    print LAB_CONF "# pxelinux.pl " . POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime() ) . " for $vm_name ($search_uuid)\n";
    print LAB_CONF Data::Dumper->Dump( [$LAB], [qw(LAB)] );
    close(LAB_CONF);

    # these can be set by the force boot handling above
    $pxelinux_config_url = $base_url . "/default" unless ($pxelinux_config_url);
    $bootinfo            = "all is fine"          unless ($bootinfo);
    print header(
                  -status => "302 VM is $vm_name and $bootinfo" . ( $has_changed ? ", some hosts changed" : "" ),
                  -type => 'text/plain',
                  -location => $pxelinux_config_url
    );
} else {

    # if the VM is not found then also give some error text
    if ( Config( "pxelinux", "redirect_unknown_to_default" ) ) {
        print header(
                      -status   => '302 VM not found',
                      -type     => 'text/plain',
                      -location => $base_url . "/default"
        );
    } else {
        print header( -status => 404,
                      -type   => 'text/plain' );
    }
    print "No VM found for '$search_uuid'\n";
}

#print Data::Dumper->Dump([\%CONFIG,\%VM,$LAB],[qw(CONFIG VM LAB)]);
