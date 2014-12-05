#!/usr/bin/perl

# rebuild_state_data.pl - Rebuild lab.conf and DHCP config from VMs in vSphere.

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use LML::Common;
use LML::VMware;
use LML::VM;
use LML::Config;
use LML::VMpolicy;
use LML::DHCP;
use LML::Lab;
use Data::Dumper;

my $C   = new LML::Config();
my $LAB = new LML::Lab( "/tmp/foobar-$$", 1 );

$LAB->update_hosts(get_hosts);
$LAB->update_networks(get_networks);
$LAB->update_datastores(get_datastores);
$LAB->update_folders(get_folders);

# get a complete dump from vSphere - this is expensive and takes some time
my $ALL_VM = get_all_vm_data();

my $vmcount = 0;
my $totalcount = 0;
my $invalidcount = 0;
my $unmanagedcount = 0;
foreach my $VM_HASH (values %$ALL_VM) {
	$totalcount++;
	my $VM = new LML::VM($VM_HASH);
	$VM->set_networks_filter( $C->get_array( "vsphere", "networks" ) );
	my $Policy = new LML::VMpolicy( $C, $VM );
	if ( $VM->get_filtered_macs and not $Policy->ignore_vm_by_path ) {
		my $vm_dns_domain = $C->appenddomain( ( $VM->networks() )[0] );
		$VM->set_dns_domain( $vm_dns_domain );
		my @extra_dns_check_zones = map { $C->get_array( "dnscheckzones", $_ ) } $VM->networks;
		my @policyresult = (
                              $Policy->validate_vm_name,                           $Policy->validate_hostrules_pattern,
                              $Policy->validate_dns_zones(@extra_dns_check_zones), $Policy->validate_contact_user,
# For data recovery keep the expired VMs :-)
#$Policy->validate_expiry,                            
# Strangely this adds empty VM sections in lab.conf
#$Policy->validate_vm_dns_name($LAB),
                              $Policy->validate_network_assignment,                $Policy->validate_path,
			);
		Debug(Data::Dumper->Dump([\@policyresult],["policyresult"]));
		if (not @policyresult) {
			print "Adding ".$VM->name."\n";
			$vmcount++;
			$LAB->update_vm($VM)
		} else {
			$invalidcount++;
			print "Skipping invalid VM ".$VM->name."\n\t";
			print join("\n\t",@policyresult)."\n";
		}
	} else {
		$unmanagedcount++;
		print "Skipping not managed VM ".$VM->name."\n";
	}
}
print "Total VMs: $totalcount\nAdded VMs: $vmcount\nInvalid VMs: $invalidcount\nUnmanaged VMs: $unmanagedcount\n";
$LAB->set_filename($C->labfile);

if (not $LAB->write_file( "for " . __FILE__ )) {
	die "Could not write Labfile";
}

if ($LAB->vms_to_update) {
	print join("\n",LML::DHCP::UpdateDHCP( $C, $LAB ));
}


