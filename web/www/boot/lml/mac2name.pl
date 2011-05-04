#!/usr/bin/perl
#
#
# mac2name.pl	- find Virtual Machines by mac address
#
# Authors:	
# GSS	Schlomo Schapiro <vinfo@schlomo.schapiro.org>
# 
# Copyright:	Schlomo Schapiro, Immobilien Scout GmbH
# License:	GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full text
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

connect_vi();


my $search_mac=param('mac')?param('mac'):lc($ARGV[0]);

my $vm_name="";

my %VM = search_vm();
if (scalar(keys(%VM))) {
	# scan through VMs and search for mac
	foreach my $uuid (keys(%VM)) {
		if (exists $VM{$uuid}{MAC}) {
			while (my ($mac,$network) = each(%{$VM{$uuid}{MAC}})) {
				if (lc($mac) eq $search_mac) {
					$vm_name=$VM{$uuid}{NAME};
				}
			}
		}
	}
}
Util::disconnect;
if ($vm_name) {
	print header('text/plain');
	print $vm_name."\n";
} else {
	print header(-status=>404,-type=>'text/plain');
	print "Give MAC address as query parameter 'mac' or as command line parameter\n";
	if ($search_mac) {
		print "No VM found for '$search_mac'\n";
	}
}
#print Dumper([%VM]);
