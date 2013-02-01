#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use JSON;
use LML::Common;

# input parameter, UUID of a VM
my $search_uuid;
if (param('uuid')) {
	$search_uuid=param('uuid');
} elsif (@ARGV) {
	$search_uuid=lc($ARGV[0]);
} else {
	die("Give UUID address as query parameter 'uuid' or as command line parameter\n");
}

my $VM={};
if (-r "$CONFIG{lml}{datadir}/vm.conf") {
	local $/=undef;
	open(VM_CONF,"<$CONFIG{lml}{datadir}/vm.conf") || die "Could not open $CONFIG{lml}{datadir}/vm.conf";
	flock(VM_CONF, 1) || die;
	binmode VM_CONF;
	eval <VM_CONF> || die "Could not parse $CONFIG{lml}{datadir}/vm.conf";
	close(VM_CONF);
} elsif (! exists($VM->{$search_uuid})) {
	print header(-status=>"200 No Data for VM $search_uuid found");
	exit 0;
} else {
	print header(-status=>"200 No VM Data Found");
	exit 0;
}

print header();
my %VM_DATA = %{$VM->{$search_uuid}};
print "<html><body><pre>\n".
#	escapeHTML(Data::Dumper->Dump([\%VM_DATA],[qw(VM_DATA)]))."\n".
	to_json(\%VM_DATA,{utf8 => 0, pretty => 1, allow_blessed => 1})."\n".
	"</pre></body></html>\n";

1;
