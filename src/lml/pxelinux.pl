#!/usr/bin/perl
#
#
# pxelinux.pl	Lab Manager Light pxelinux interface
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
use LML::Lab;
use Data::Dumper;

my $C = new LML::Config();    # implicitly also fills %LML::Common::CONFIG

# install die handler to report fatal errors
$SIG{__DIE__} = sub {
    die @_ if $^S;                     # see http://perldoc.perl.org/functions/die.html at the end
    return unless ( $C->get( "lml", "showfatalerrors" ) and Config( "pxelinux", "fatalerror_template" ) );
    my $message = shift;
    chomp($message);                   # remove trailing newlines
    $message =~ s/\n/; /;              # turn message into single line
    print header( -status => '200 Fatal Error', -type => 'text/plain' );
    my $body = join( "\n", @{ $C->get( "pxelinux", "fatalerror_template" ) } ) . "\n";
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


# prepare some configuration variables
my @vsphere_networks = ();                                       # list of network names for which LML is responsible.
my $config_vsphere_networks = $C->get( "vsphere", "networks" );
if ($config_vsphere_networks) {
    if ( ref($config_vsphere_networks) eq "ARRAY" ) {
        @vsphere_networks = @{$config_vsphere_networks};
    } else {
        @vsphere_networks = ($config_vsphere_networks);
    }
}

# read history to detect renamed VMs and to be able to update the DHCP
my $LAB = new LML::Lab($C->labfile);
# find VM
my $VM = new LML::VM($search_uuid);
my $result = new LML::Result( $C, url() );

my @body; # body to return to HTTP client

# if there are VMs and if we find the VM we are looking for:
if ( defined $VM and %{$VM} and $VM->uuid and $search_uuid eq $VM->uuid ) {
    $vm_name = $VM->name;

    # check if we should handle this VM
    $VM->set_networks_filter(@vsphere_networks);
    if ( $VM->get_filtered_macs ) {
        # This VM uses our managed network
        
        # ensure that VM will only boot from network
        if ( $C->get( "modifyvm", "forcenetboot" ) and not $VM->forcenetboot ) {
            # modify VM if configured and current setting not as it should be (because the reconfigure VM task takes time)
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
        
        
        #Debug(Data::Dumper->Dump([\@error],["error"]));
    
    
        # up till here we have only checks that verify the VM.
        # in case of errors stop processing so that we do not create host records anywhere as long
        # as some conditions are unmet.
    
        # we only modify something if there are no errors
        if ( not $result->get_errors ) {
            if ($LAB->update_host($VM)){
                # update DHCP only if some host data changed because reloading dhcp server takes a while
                $result->add_error( UpdateDHCP($LAB) );
            }
        }
    
        if ( @error = $result->get_errors ) {
            # got some errors, report to client
            $result->set_status(200,"for",$vm_name,$search_uuid);
            
            # build body with error page
            push(@body,@{ $C->get( "pxelinux", "error_main" ) });
            push(@body,"menu title " . $C->get( "pxelinux", "error_title" ) . " " . $vm_name);
            my $c = 1;
            foreach my $e (@error) {
                $e =~ s/\^/^^/g;                                                   # pxelinux menu uses ^ to mark keyboard shortcuts. ^^ comes out as plain ^
                push(@body,"label l$c","menu label $c. $e");
                push(@body,@{ $C->get( "pxelinux", "error_item" ) });
                $c++;
            }
        
            
        } else {
            # if the VM is found and all is fine then redirect to default PXE configuration
            # here we must have a VM as otherwise we already exited before
            # dump $LAB to file only if all is fine. This makes sure that LML stays with the old view of the lab for some kind of
            # hard to catch errors.
            if (not $LAB->write_file("for ".$vm_name." (".$search_uuid.")")) {
                die "Strangely writing LAB produced a 0-byte file.\n";
            }
    
            $result->set_redirect_target = $C->get("pxelinux","default_redirect") unless ($result->redirect_target); # redirect to default if no redirect is set    
            $result->set_status(302,"VM is",$vm_name);
        }
        
    } else {
        # VM does not use any of our managed networks.
        $result->set_status(404,"VM does not match LML networks and is out of scope");
        @body = ("VM does not match LML networks and is out of scope");
    }
} else {

    my $message = "No VM found for '$search_uuid'";
    # if the VM is not found then also give some error text
    if ( $C->get( "pxelinux", "redirect_unknown_to_default" ) ) {
        $result->set_status(302,$message);
        $result->set_redirect_target($C->get("pxelinux","default_redirect"));
    } else {
        $result->set_status(404,$message);
    }
    push(@body,$message);
}
# disconnect from VI
Util::disconnect();

print $result->render(@body);