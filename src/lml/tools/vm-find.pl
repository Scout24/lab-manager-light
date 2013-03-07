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
if ( my @customfields = keys(%{get_custom_fields()}) ) {
    print( "Custom Attributes:\n\t" . join( "\n\t", @customfields ) . "\n" );
} else {
    print("No Custom Attributes defined - You will not have much fun using LML without them.\n");
}

# display hosts
if ( my @hosts = keys(%{get_hosts()}) ) {
    print( "ESX Hosts:\n\t" . join( "\n\t", @hosts ) . "\n" );
} else {
    print("No ESX Hosts found - You will not have much fun using LML without them.\n");
}

# search for VM
print( "Searching for VMs" . "\n" );
my $VM = get_all_vm_data( @ARGV ? ( "config.name" => qr($ARGV[0])i ) : () );
# bail out if no VMs found
die( "No VMs found " . ( @ARGV ? "matching '" . $ARGV[0] . "'  - check your search criteria" : "to work with" ) . " !\n" )
  unless ( scalar( keys( %{$VM} ) ) );

print("\n");
print( " UUID                                  PATH" . "\n" );
print("\n");

my $display_filter_vm_path = $C->get( "gui", "display_filter_vm_path" );
# go over virtual machines and do the job
foreach my $uuid ( keys( %{$VM} ) ) {
    # human-readable name for VM
    my $vmname          = $VM->{$uuid}{NAME};
    my $display_vm_path = $VM->{$uuid}{PATH};

    if ($display_filter_vm_path) {
        $display_vm_path =~ s/$display_filter_vm_path/$1/;
    }

    printf( "%s  %s\n", $uuid, $display_vm_path );
}
print("\n");
printf( "Found %d VMs\n", scalar( keys( %{$VM} ) ) );
Debug( Data::Dumper->Dump( [$VM], [qw(VM)] ) );
