#!/usr/bin/perl
#
# give VM name regex as command line argument, default is to find all VMs
# set LML_DEBUG=1 for debug output

use strict;
use warnings;

# end of user configuration

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::Bin/../lib";

use LML::Common;
use LML::Config;
use LML::VMware;

my $C = new LML::Config();

# connect to VMware
print( "Connecting to VI" . "\n" );
connect_vi();

# display custom fields
my @customfields = keys(get_custom_fields());
print("Custom Attributes:\n\t".join("\n\t",@customfields)."\n");

# display hosts
my @hosts = keys(get_hosts);
print("ESX Hosts:\n\t".join("\n\t",@hosts)."\n");

# search for VM
print( "Searching for VMs" . "\n" );
my $VM = get_all_vm_data(
                          @ARGV ? ( "config.name" => qr($ARGV[0])i ) : ()
);
# bail out if no VMs found
die("No VMs found to work with - check your search criteria !") unless ( scalar( keys( %{$VM} ) ) );

print("\n");
print( " UUID                                  PATH" . "\n" );
print("\n");

# go over virtual machines and do the job
foreach my $uuid ( keys( %{$VM} ) ) {
    # human-readable name for VM
    my $vmname = $VM->{$uuid}{NAME};
    my $vmpath = $VM->{$uuid}{PATH};

    printf( "%s  %s\n", $uuid, $vmpath );
}
print("\n");
printf( "Found %d VMs\n", scalar( keys( %{$VM} ) ) );
Debug( Data::Dumper->Dump( [$VM], [qw(VM)] ) );
