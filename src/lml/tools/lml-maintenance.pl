#!/usr/bin/perl
#
# lml-maintenance.pl Lab Manager Light maintenance script
#
# * Remove obsolete machines from lab.conf
#
# IMPORTANT: If an ESX server is disconnected from the vCenter server, the VM data
#            is still accessible. Therefore this script won't delete VMs from that
#            disconnected ESX server!

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Common;
use LML::VMware;
use LML::DHCP;
use LML::Lab;
use LML::VM;
use Carp;

sub write_vm_file {
    # Purpose: Takes an hashref with vm data and dump it to
    #          the appropriate file
    # Returns: TRUE if ok, FALSE if errors occured

    # get the parameter
    my $VM = shift;

    # open and write
    my $vmfile = Config( "lml", "datadir" ) . "/vm.conf";
    open( VM_CONF, ">", $vmfile ) || die "Could not open '$vmfile' for writing\n";
    flock( VM_CONF, 2 ) || die;
    print VM_CONF "# " . __FILE__ . " " . POSIX::strftime( "%Y-%m-%d %H:%M:%S\n", localtime() ) . "\n";
    print VM_CONF Data::Dumper->Dump( [$VM], [qw(VM)] );
    close(VM_CONF);
}

sub maintain_labfile($$) {
    # initialize needed variables
    my $C = shift;
    carp( "1st argument must be LML::Config object and not " . ref($C) ) unless ( ref($C) eq "LML::Config" );
    my $VM_ALL      = shift; # this is a hash of LML::VM data structures
    my $labfile = $C->labfile;
    my @error   = ();

    my $LAB = new LML::Lab($labfile);
    # go through our known VM list and delete host from that list
    # if they are not in the actual VM list we got previously
    my $hosts_removed = 0;
    for my $uuid ( $LAB->list_hosts ) {
        if ( exists( $VM_ALL->{$uuid} ) ) {
            my $VM = new LML::VM( $VM_ALL->{$uuid} );
            $VM->set_networks_filter($C->vsphere_networks); # set network filter
            $LAB->update_vm( $VM ) ;
        } else {
            # remember that we deleted a host
            $hosts_removed++;
            # delete the host from the lab hash
            $LAB->remove($uuid);                
        }
    }

    # dump $LAB to file only if all is fine. This makes sure that LML stays with
    # the old view of the lab for some kind of hard to catch errors.
    if ( $hosts_removed > 0 or $LAB->vms_to_update ) {
        $LAB->write_file( "by " . __FILE__ );
    }
    if ( $LAB->vms_to_update ) {
        # rewrite the DHCP configuration with the new data
        push( @error, LML::DHCP::UpdateDHCP( $C, $LAB ) );
    }

    # Return the error array
    return @error;
}

# main() code when running as stand-alone program
unless (caller) {
    my $C = new LML::Config;

    # connect to vSphere
    connect_vi();

    # initialize needed variables
    my $vm_name = "";
    my @error   = ();

    # get a complete dump from vSphere - this is expensive and takes some time
    my $VM = get_all_vm_data();

    # dump %VM to file, ATM we don't use this information any more.
    write_vm_file($VM);

    # $LAB describes our internal view of the lab that lml manages
    # used mainly to react to renamed VMs or VMs with changed MAC adresses
    push( @error, maintain_labfile( $C, $VM ) );

    # if errors occured, print them out
    if ( scalar(@error) ) {
        print STDERR "ERROR: " . join( "\nERROR: ", @error ) . "\n";
        exit 1;
    }
}
