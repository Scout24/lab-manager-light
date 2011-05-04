#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;

# $LAB describes our internal view of the lab that lml manages
# used mainly to react to renamed VMs or VMs with changed MAC adresses
my $LAB={};
if (-r "$CONFIG{lml}{datadir}/lab.conf") {
	local $/=undef;
	open(LAB_CONF,"<$CONFIG{lml}{datadir}/lab.conf") || die "Could not open $CONFIG{lml}{datadir}/lab.conf";
	flock(LAB_CONF, 1) || die;
	binmode LAB_CONF;
	eval <LAB_CONF> || die "Could not parse $CONFIG{lml}{datadir}/lab.conf";
	close(LAB_CONF);
} else {
	# set up empty structure if our data file is missing
	$LAB->{HOSTS} = {};
}
die '$LAB is empty' unless (scalar(%{$LAB}));


my $VM={};
{
	local $/=undef;
	open(VM_CONF,"<$CONFIG{lml}{datadir}/vm.conf") || die "Could not open $CONFIG{lml}{datadir}/vm.conf";
	flock(VM_CONF, 1) || die;
	binmode VM_CONF;
	eval <VM_CONF> || die "Could not parse $CONFIG{lml}{datadir}/vm.conf";
	close(VM_CONF);
}
die '$VM is empty' unless (scalar(%{$VM}));

print header();
print <<EOF;
<html><head>
<title>Lab Manager Light - Overview</title>
<script type="text/javascript" src="lib/js/table.js"></script>
</head><body>
<h1>Lab Manager Light - Overview</h1>
EOF

print <<EOF;
<h2>Managed Systems</h2>
<table class="table-autosort:0 table-autofilter" cellpadding="3" cellspacing="0">
EOF
print thead(
		Tr({-valign=>"top"},
			th({-title=>"Click to sort",-class=>"table-sortable:alphanumeric filterable"},'Hostname'),
			th({-title=>"Click to sort",-class=>"table-sortable:alphanumeric"},"VM Path"),
			th({-title=>"Click to sort",-class=>"table-sortable:alphanumeric table-filterable"},"Contact User ID"),
			th({-title=>"Click to sort",-class=>"table-sortable:date"},"Expires"),
			)
#		Tr(
#			th('<input name="filter" size="8" onkeyup="Table.filter(this,this)">').
#			th('&nbsp;').
#			th('&nbsp;').
#			th('&nbsp;')
#		)
	)."\n".
"<tbody>\n";

for my $uuid (keys(%{$LAB->{HOSTS}})) {
	my $expires = "unknown";
	eval { $expires=DateTime::Format::Flexible->parse_datetime($VM->{$uuid}->{CUSTOMFIELDS}->{$CONFIG{vsphere}{expires_field}} , 
									european => ($CONFIG{vsphere}{expires_european}?1:0))->ymd(); };
	my $display_vm_path = $VM->{$uuid}->{PATH};
	if (exists($CONFIG{GUI}{DISPLAY_FILTER_VM_PATH}) and $CONFIG{GUI}{DISPLAY_FILTER_VM_PATH}) {
		$display_vm_path =~ s/$CONFIG{GUI}{DISPLAY_FILTER_VM_PATH}/$1/;
	}
	print Tr(td[
			$LAB->{HOSTS}->{$uuid}->{HOSTNAME},
			$display_vm_path,
			$VM->{$uuid}->{CUSTOMFIELDS}->{$CONFIG{vsphere}{contactuserid_field}},
			$expires,
		])."\n";
}
print <<EOF;
</tbody>
</table>

<h2>Configuration</h2>
<div id="configshow"><a href="#" onclick="document.getElementById('configdump').style.display='block';document.getElementById('configshow').style.display='none'">Show configuration</a></div>
<div id="configdump" style="display:none">
<p>Config file is <code>/etc/lml.conf</code></p>
<pre>
EOF
my $confdata;
{
	local $/=undef;
	open FILE, "</etc/lml.conf";
	binmode FILE;
	$confdata = escapeHTML(<FILE>);
	close FILE;
}
$confdata =~ s/$CONFIG{vsphere}{password}/*******************/g;
print <<EOF;
$confdata
</pre>
</div>
<hr/>
Lab Manager Light is licensed under the <a href="http://www.gnu.org/licenses/gpl.html" target="_blank">GNU General Public License</a>.<br/>
Written by <a href="http://schapiro.org/schlomo">Schlomo Schapiro</a>.
</body></html>
EOF
