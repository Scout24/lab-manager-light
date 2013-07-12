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

use LML::Common;
use LML::Config;
use LML::DHCP;
use LML::Lab;
use LML::VMware;
use LML::VMmodify;

# Initialization
my $header_sent = 0;
my $action;
my $action_detonate;
my $action_destroy;
my $show_help;
my @vm_names;

# Get the lml configuration
my $C = new LML::Config();

# Are we in CGI context?
if ( param('action') ) {
    # Get the action
    if ( param('action') eq 'detonate' ) {
        $action_detonate = 1;

    } elsif ( param('action') eq 'destroy' ) {
        $action_destroy = 1;
    }

    # Assemble hosts array if existent
    if ( param('hosts') ) {
        @vm_names = param('hosts');
    } else {
        print header( -status => '400 No hosts given (hosts=)' );
        print "No hosts were selected";
        exit 0;
    }

    # Ok commandline context
} else {
    # Get the long commandline options
    GetOptions(
                "detonate" => \$action_detonate,
                "destroy"  => \$action_destroy,
                "help"     => \$show_help
    );

    # Just print the usage if the option is set and then quit
    if ($show_help) {
        print_usage();
        exit 1;
    }

    # Get the vm name
    if (@ARGV) {
        # Check the command option consistence
        if ( $action_detonate && $action_destroy ) {
            error("The option --detonate and --destroy can not be used at the same time, quit ...");
        }

        # Check if paramter assembly is correct
        if ( ( not $action_detonate ) && ( not $action_destroy ) ) {
            error("No option --detonate or --destroy is given! Exit...");
        }

        # Save the delivered hostname(s)
        foreach (@ARGV) {
            push( @vm_names, $_ );
        }

        # If no vm name is given
    } else {
        error("The name of the vm(s) is not given, quit ...");
    }
}

# Connect to VMware
connect_vi();

foreach my $vm_name (@vm_names) {
    # Translate the vm name to its uuid
    my $VM = get_vm_by_name($vm_name);

    # Check the success
    if ( not $VM ) {
        error("Unable to find entry in lab file for vm \"$vm_name\", quit ...");
    }

    if ($action_detonate) {
        # Set the forceboot value to ON
        set_forceboot( $C, $VM->uuid );

        # Reboot the vm
        $VM->reboot();

    } elsif ($action_destroy) {
        # Switch off the vm
        $VM->poweroff();

        # Finally destroy the vm
        $VM->destroy();
    }
}

# Print an HTML success header if we are in CGI context
if ( exists $ENV{GATEWAY_INTERFACE} ) {
    print header( -status => '200 vm created' );
}

# Compose a error output
sub error {
    my $message   = shift;
    my $linebreak = "\n";

    # Print html header before anything else if CGI is used
    if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '500 $message' );
        $linebreak = "<br>";
    }

    print $message. $linebreak;

    exit 1;
}

# Translate the given name to the appropriate uuid.
# Make use of our lab file as data source
sub get_vm_by_name {
    my $vm_name = shift;

    # Get an object of our lab file
    my $LAB = new LML::Lab( $C->labfile );

    # Loop through the lab file to find the correct vm
    foreach my $uuid ( $LAB->list_hosts() ) {
        # Try to get an vm object for the actual uuid
        if ( my $VM = $LAB->get_vm($uuid) ) {
            if ( $VM->name eq $vm_name ) {
                # Return the found vm object, if it is the one we looking for
                return $VM;
            }
        }
    }

    # Return error as default, if nothing was found
    return 0;
}

sub print_usage {
    print "vm-create.pl <OPTION> [vmname1, vmname2, ...]\n\n";

    print "   --detonate \t\t Set forceboot and reboot the virtual machine\n";
    print "   --destroy \t\t Wipe the vm completely\n";
}

