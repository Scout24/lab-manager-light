#!/usr/bin/perl
#
# lml-maintenance.pl Lab Manager Light maintenance script
#
# * Remove obsolete machines from lab.conf
#

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Common;
use LML::VMware;
use LML::DHCP;

sub maintain_labfile($) {
    # Purpose:
    # Returns:

    # initialize needed variables
    my $VM      = shift;
    my $LAB     = {};
    my $labfile = Config( "lml", "datadir" ) . "/lab.conf";
    my @error   = ();

    if ( -r $labfile ) {
        # reset INPUT_RECORD_SEPARATOR
        local $/ = undef;

        # open the labfile and lock it
        open( LAB_CONF, "+<", $labfile )
          || die "Could not open '$labfile' for reading and writing\n";
        flock( LAB_CONF, 2 ) || die;
        binmode LAB_CONF;
        eval <LAB_CONF> || die "Could not parse $labfile\n";

        # $LAB is defined in labfile, test if we got it
        die '$LAB is empty' unless ( scalar( %{$LAB} ) );

        # go through our known VM list and delete host from that list
        # if they are not in the actual VM list we got previously
        my $hosts_removed = 0;
        for my $uuid ( keys( %{ $LAB->{HOSTS} } ) ) {
            if ( !exists( $$VM{$uuid} ) ) {
                print "Removing $uuid " . $LAB->{HOSTS}->{$uuid}->{HOSTNAME} . " from inventory\n";
                # remember that we deleted a host
                $hosts_removed++;
                # delete the host from the lab hash
                delete( $LAB->{HOSTS}->{$uuid} );
            }
        }

        # dump $LAB to file only if all is fine. This makes sure that LML stays with
        # the old view of the lab for some kind of hard to catch errors.
        if ( $hosts_removed > 0 ) {
            # empty the file
            seek( LAB_CONF, 0, 0 );
            # dump the adjusted lab hash
            print LAB_CONF "# lml-maintenance.pl " .
              POSIX::strftime( "%Y-%m-%d %H:%M:%S\n", localtime() ) . "\n";
            print LAB_CONF Data::Dumper->Dump( [$LAB], [qw(LAB)] );
            truncate( LAB_CONF, tell(LAB_CONF) );
        }
        close(LAB_CONF);

        # rewrite the DHCP configuration with the new data
        # the 
        push( @error, UpdateDHCP($LAB) );
    } else {
        push( @error, "'$labfile' not found\n" );
    }

    # Return the error array
    return @error;
}

# main() code when running as stand-alone program
unless (caller) {
    LoadConfig();

    # connect to vSphere
    connect_vi();

    # initialize needed variables
    my $vm_name = "";
    my @error   = ();

    # get a complete dump from vSphere - this is expensive and takes some time
    my %VM = search_vm();

    # dump %VM to file
    write_vm_file( \%VM );

    # $LAB describes our internal view of the lab that lml manages
    # used mainly to react to renamed VMs or VMs with changed MAC adresses
    push( @error, maintain_labfile( \%VM ) );

    # if errors occured, print them out
    if ( scalar(@error) ) {
        print STDERR "ERROR: " . join( "\nERROR: ", @error ) . "\n";
        exit 1;
    }
}
