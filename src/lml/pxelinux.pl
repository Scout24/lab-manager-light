#!/usr/bin/perl

# pxelinux.pl: Lab Manager Light pxelinux interface

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use URI::Escape;
use LML::Common;
use LML::VMware;
use LML::VM;
use LML::Config;
use LML::VMpolicy;
use LML::DHCP;
use LML::Result;
use LML::Lab;
use Data::Dumper;
use JSON;

my $C             = new LML::Config();    # implicitly also fills %LML::Common::CONFIG
my $vm_name       = "";
my $append_domain = "";
my @error         = ();
my $search_uuid;                          # input parameter, UUID of a VM

# install die handler to report fatal errors
$SIG{__DIE__} = sub {
    die @_ if $^S;                        # see http://perldoc.perl.org/functions/die.html at the end
    return unless ( $C->get( "lml", "showfatalerrors" ) and Config( "pxelinux", "fatalerror_template" ) );
    my $message = shift;
    chomp($message);                      # remove trailing newlines
    $message =~ s/\n/; /;                 # turn message into single line
    print header( -status => '200 Fatal Error', -type => 'text/plain' );
    my $body = $C->get( "pxelinux", "fatalerror_template" ). "\n";
    $body =~ s/MESSAGE/$message/;
    print $body;
};

# get it from CGI context
if ( param('uuid') ) {
    $search_uuid = param('uuid');

    # or if we called via commandline
} elsif (@ARGV) {
    $search_uuid = lc( $ARGV[0] );

    # else UUID is missing, quit here
} else {
    die("Give UUID address as query parameter 'uuid' or as command line parameter\n");
}

# connect to vSphere
connect_vi();

# read history to detect renamed VMs and to be able to update the DHCP
my $LAB = new LML::Lab( $C->labfile );
# find VM
my $VM = new LML::VM($search_uuid);
my $result = new LML::Result( $C, url() );

my @body;    # body to return to HTTP client

# if there are VMs and if we find the VM we are looking for:
if ( defined $VM and %{$VM} and $VM->uuid and $search_uuid eq $VM->uuid ) {
    $vm_name = $VM->name;
    $append_domain = $C->get( "dhcp", "appenddomain" );

    # set redirect paramters
    $result->set_redirect_parameter( $C->get_proxy_parameter( hostname => $vm_name . "." . $append_domain ) );

    # check if we should handle this VM
    $VM->set_networks_filter( $C->get_array("vsphere","networks") );
    if ( $VM->get_filtered_macs ) {
        # This VM uses our managed network

        # Set dns domain of VM from first network card
        $VM->set_dns_domain($C->appenddomain(($VM->networks())[0]));
        
        my @extra_dns_check_zones = map { $C->get_array("dnscheckzones",$_) } $VM->networks;
        
        my $Policy = new LML::VMpolicy( $C, $VM );

        $Policy->handle_unmanaged();

        $result->add_error( $Policy->validate_vm_name,      $Policy->validate_hostrules_pattern, $Policy->validate_dns_zones(@extra_dns_check_zones),
                            $Policy->validate_contact_user, $Policy->validate_expiry,            $Policy->validate_vm_dns_name($LAB),
                            $Policy->validate_network_assignment
        );

        $Policy->handle_forceboot($result);

        Debug( "VM Validation result: " . join( ", ", $result->get_errors ) );
        #Debug(Data::Dumper->Dump([\@error],["error"]));

        # up till here we have only checks that verify the VM.
        # in case of errors stop processing so that we do not create host records anywhere as long
        # as some conditions are unmet.

        # ensure that VM will only boot from network
        if ( $C->get( "modifyvm", "forcenetboot" ) and not $VM->forcenetboot ) {
            # modify VM if configured and current setting not as it should be (because the reconfigure VM task takes time)
            $VM->activate_forcenetboot;
        }

        # we only modify our state data if there are no errors
        if ( not $result->get_errors ) {
            if ( $LAB->update_vm($VM) ) {
                # update DHCP only if some host data changed because reloading dhcp server takes a while
                $result->add_error( LML::DHCP::UpdateDHCP( $C, $LAB ) );
            }
        }

        if ( @error = $result->get_errors ) {
            # got some errors, report to client
            $result->set_status( 200, "for", $vm_name, $search_uuid );

            # build body with error page
            
            
            
            my $error_data = {
            	NAME =>  $vm_name,
            	HAS_ERRORS => scalar(@error),
            	ERRORS => \@error
            };
            my $encoded_error_data = uri_escape(to_json( $error_data, { utf8 => 0, pretty => 1, allow_blessed => 1, canonical => 1 } ));
            my $error_main = $C->get( "pxelinux", "error_main" );
            my $url = "../lml/backgroundimage.pl?data=" . $encoded_error_data;
            $error_main =~ s/URL/$url/;
            
            push( @body, $error_main );
            push( @body, "menu title " . $C->get( "pxelinux", "error_title" ) . " " . $vm_name );
            my $c = 1;
            foreach my $e (@error) {
                $e =~ s/\^/^^/g;    # pxelinux menu uses ^ to mark keyboard shortcuts. ^^ comes out as plain ^
                push( @body, "label l$c", "menu label $c. $e" );
                push( @body, $C->get( "pxelinux", "error_item" ) );
                $c++;
            }

        } else {
            # if the VM is found and all is fine then redirect to default PXE configuration
            # here we must have a VM as otherwise we already exited before

            # dump $LAB to file only if all is fine. This makes sure that LML stays with the old view
            # of the lab for some kind of hard to catch errors.

            # first update the info about ESX hosts
            $LAB->update_hosts(get_hosts);
            $LAB->update_networks(get_networks);
            $LAB->update_datastores(get_datastores);
            if ( not $LAB->write_file( "for " . $vm_name . " (" . $search_uuid . ")" ) ) {
                die "Strangely writing LAB produced a 0-byte file.\n";
            }
            if ( my $default_redirect = $C->get( "pxelinux", "default_redirect" ) ) {
                if ( !$result->redirect_target ) {
                    # redirect to default if no redirect is set
                    $result->set_redirect_target($default_redirect);
                    $result->set_statusinfo("redirect to default_redirect from LML config");
                }
                $result->set_status( 302, "VM is", $vm_name );
            } else {
                $result->set_status( 404, "VM is", $vm_name );
                @body = ("VM successfully passed all tests.");
            }
        }

    } else {
        # VM does not use any of our managed networks.
        if ( my $othervm_redirect = $C->get( "pxelinux", "othervm_redirect" ) ) {
            $result->set_redirect_target($othervm_redirect);
            $result->set_statusinfo("redirect to othervm_redirect from LML config");
            $result->set_status( 302, "VM is", $vm_name );
        } else {
            $result->set_status( 404, "VM does not match LML networks and is out of scope" );
            push( @body, "VM does not match LML networks and is out of scope" );
        }
    }
} else {
    # set redirect paramters
    $result->set_redirect_parameter( $C->get_proxy_parameter( hostname => 'noname' ) );

    # if the VM is not found then also give some error text
    my $message = "No VM found for $search_uuid";
    if ( my $unknown_redirect = $C->get( "pxelinux", "unknown_redirect" ) ) {
        $result->set_status( 302, $message );
        $result->set_redirect_target($unknown_redirect);
        $result->set_statusinfo("redirect to unknown_redirect from LML config");
    } else {
        $result->set_status( 404, $message );
        push( @body, $message );
    }
}

print $result->render(@body);
