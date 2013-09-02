#!/usr/bin/perl

# Purpose: Deletes single or multiple VM(s) identified by their name. The machine(s) will be
#          powered off if still on and then the machine(s) will be completely deleted including
#          the files in datastore
#
# License: GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full text

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use CGI ':standard';
use JSON;
use Getopt::Long;

use LML::Config;
use LML::TokenReplacer;
use LML::Common;
use LML::VM;
use LML::VMware;
use LML::Lab;
use LML::DHCP;

# Initialization
my $header_sent = 0;
my $action      = param("action") ? param("action") : undef;
my @hosts       = param("hosts") ? param("hosts") : ();

if ( ( $action eq "detonate" or $action eq "destroy" ) and @hosts ) {
    # Get the lml configuration
    my $C = new LML::Config();

    my $LAB     = new LML::Lab( $C->labfile );
    my @errors  = ();                            # collect errors
    my $removed = 0;
    foreach my $target (@hosts) {
        my $VM = $LAB->get_vm($target);
        # Check the success
        if ($VM) {
            if ( $action eq "detonate" ) {
                # Set the forceboot value to ON
                my $forceboot_field = $C->get( "vsphere", "forceboot_field" );
                if ( $VM->set_custom_value( $forceboot_field, "ON" ) ) {
                    $VM->reset();                # Restart the vm after activating force boot
                }
                else {
                    push @errors, "Could not set custom value '$forceboot_field' = ON";
                }
            }
            else {
                # ATM this could be only destroy
                $VM->poweroff();
                $VM->destroy();
                $LAB->remove( $VM->uuid );       # remove VM from lab data
                $removed++;
            }
            my $triggercommand = $C->get( "triggers", "vm".$action );
            if ($triggercommand) {
                my $tr = new LML::TokenReplacer($C->get_proxy_parameter,$VM);
                $triggercommand = $tr->replace($triggercommand);
                my $result = qx($triggercommand 2>&1);
                Debug("delete triggercommand '$triggercommand' said:\n$result") if ($isDebug);
                if ( $? > 0 ) {
                    warn "delete trigger command '$triggercommand' failed:\n$result";
                    push( @errors, "Could not run delete triggercommand, please call for help" );
                }

            }
        }
        else {
            push @errors, "Unable to find vm '$target'";
        }
    }
    if ($removed) {
        # always write LAB file, also creates new one if it did not exist before
        $LAB->write_file( "by " . __FILE__ );
    }
    if ( $LAB->vms_to_update ) {
        # rewrite the DHCP configuration with the new data, but only if there is a change that was relevant for DHCP
        push( @errors, LML::DHCP::UpdateDHCP( $C, $LAB ) );
    }
    if (@errors) {
        my $msg = "ERRORS: " . join( ", ", @errors );
        print header( -status => "500 $msg" )
          . start_html( -title => "LML VM Control" )
          . p("The following ERRORS occured:")
          . ul( li( \@errors ) )
          . end_html . "\n";
    }
    else {
        # Print HTML success header
        print header( -status => "200 $action " . scalar(@hosts) . " target(s)" );

        # Print out json formatted array
        print encode_json( \@hosts ) . "\n";
    }
}
else {
    # error handling for invalid or missing args
    my $msg = "Arg ERROR: action must be detonate or destroy, hosts must contain at least one target";
    print header( -status => "500 $msg" ) . start_html( -title => "LML VM Control" ) . p($msg) . end_html . "\n";
}

1;
