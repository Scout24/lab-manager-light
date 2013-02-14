#!/usr/bin/perl
#
#
# vm-find.pl	- find Virtual Machines by Datacenter Inventory Path or special tag
#
# Authors:	
# GSS	Schlomo Schapiro <lml@schlomo.schapiro.org>
# 
# Copyright:	Schlomo Schapiro, Immobilien Scout GmbH
# License:	GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full text
#
#
# Usage:
# ---------------
#
# Report VMs by UUID and VM name
#
# Select VMs either by Inventory Path and/or by special custom field (defaults to easyVCB).
#
# To select VMs by Inventory Path specify one or several paths as command line arguments.
#
# To select VMs by custom field, use the --tag option. The default for the custom field is easyVCB
# but it can be changed with by specifying a different field name as a parameter for --tag
# The field should contain 1, true or yes to enable a VM for inclusion. All other VM will be ignored
#
# Both methods can be combined, e.g. select all tagged VM from within a specific Inventory Path
#
# Use --verbose 1 to enable verbose output, also helps to understand the internal names of the 
# Inventory Paths. Alternatively use the MOB Browser to surf your data centre.
#
# Result:
# ---------------
# The list of UUIDs and VM names (separated by a blank) will be written to STDERR, debugging output to
# STDOUT (because of crappy VMWare Util package Util::trace). You might have to redirect STDERR to
# a file if you want to catch it properly.
#
# History:
# 2008-04-06	GSS Initial Version
# 2008-06-##	GSS Adapted to current (1.1) easyVCB.pl and libraries
# 2008-07-02	GSS GPL name correction
# 2008-10-30	GSS Show all custom tags
# 2010-10-13	GSS Migrate from easyVCB to vinfo
# 2013-01-14    GSS Refactor and stop recording history in this list. Check the github commit history instead.
#

use strict;
use warnings;

# end of user configuration

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::Bin/../lib";

use LML::Common;
use LML::VMware;

my $PRODUCT = "vm-find";
my $COPYRIGHT = "Copyright 2011 by Schlomo Schapiro, Immobilien Scout GmbH";
my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";



LoadConfig();

print("$PRODUCT Version $LML_VERSION\n");
print($COPYRIGHT."\n");
print($LICENSE."\n");
print("\n");

# connect to VMware
print("Connecting to VI"."\n");
connect_vi();

# display custom fields
my %customfields=custom_fields();
if (scalar(keys(%customfields))) {
	print("\n");
	print("The following Custom Attribute Keys are defined (use the name as an argument to --tag):"."\n");
	print("        ID  Name"."\n");
	foreach my $name (keys(%customfields)) {
		next if ($name =~ m/^com\.vmware/);
		printf("%10d: %s\n",$customfields{$name},$name);
	}
	print("\n");
}
# search for VM
print("Searching for VMs"."\n");
my %VM = search_vm(@ARGV);
# bail out if no VMs found
die("No VMs found to work with - check your search criteria !") unless(scalar(keys(%VM)));
printf("Found %d VMs\n",scalar(keys(%VM)));
print("\n");
print("\n");
print(" UUID                                  PATH"."\n");
print("\n");

# go over virtual machines and do the job
foreach my $uuid (keys(%VM)) {
	# human-readable name for VM
	my $vmname=$VM{$uuid}{NAME};
	my $vmpath=$VM{$uuid}{PATH};
	
	printf("%s  %s\n",$uuid,$vmpath);
}

print Data::Dumper->Dump([\%VM],[qw(VM)]);
