#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;

LoadConfig();

my $LAB = ReadLabFile;
my $VM = ReadVmFile;

print header();
print <<EOF;
<html><head>
	<title>Lab Manager Light - Overview</title>
	<script type="text/javascript" src="lib/js/table.js"></script>
	<script type="text/javascript" src="lib/js/jquery-1.8.3.min.js"></script>
	<script type="text/javascript" src="lib/js/jquery.cluetip.min.js"></script>
	<script type="text/javascript" src="lib/js/jquery.tabsLite.js"></script>
	<script type="text/javascript" src="lib/js/lml.js"></script>
	<link rel="stylesheet" type="text/css" href="lib/css/jquery.cluetip.css" />
	<link rel="stylesheet" type="text/css" href="lib/css/lml.css" />
</head><body>
<div id="logoframe">
	<a href="#"><img src="lib/images/LabManagerLightlogo-small.png"/></a><br/>
	Version $LML_VERSION
</div>
<div id="uparrowframe"><a href="#">&#9650;</a></div>
&nbsp;
<div id="tabs">
    <ul>
        <li><a href="#tab-1">Managed Systems</a></li>
        <li><a href="#tab-2">Configuration</a></li>
    </ul>
	<div id="tab-1">
<table class="table-autostripe table-stripeclass:alternate table-autosort:0 table-autofilter" cellpadding="3" cellspacing="0">
EOF

print thead(
    { -id => "vmlist" },
    Tr( { -valign => "top" }, th( { -title => "Click to sort", -class => "table-sortable:alphanumeric filterable" }, 'Hostname' ), th( { -title => "Click to sort", -class => "table-sortable:alphanumeric" }, "VM Path" ), th( { -title => "Click to sort", -class => "table-sortable:alphanumeric table-filterable" }, "Contact User ID" ), th( { -title => "Click to sort", -class => "table-sortable:date" }, "Expires" ), )

      #		Tr(
      #			th('<input name="filter" size="8" onkeyup="Table.filter(this,this)">').
      #			th('&nbsp;').
      #			th('&nbsp;').
      #			th('&nbsp;')
      #		)
) . "\n" . "<tbody>\n";

for my $uuid ( keys( %{ $LAB->{HOSTS} } ) ) {
    my $expires         = "unknown";
    my $contact_user_id = "unknown";
    my $display_vm_path = "<em>(no data available)</em>";
    if ( exists( $VM->{$uuid} ) ) {
        eval { $expires = DateTime::Format::Flexible->parse_datetime( $VM->{$uuid}->{CUSTOMFIELDS}->{ Config( "vsphere", "expires_field" ) }, european => ( Config( "vsphere", "expires_european" ) ? 1 : 0 ) )->ymd(); };
        $display_vm_path = $VM->{$uuid}->{PATH};
        if ( my $display_filter_vm_path = Config( "gui", "display_filter_vm_path" ) ) {
            $display_vm_path =~ s/$display_filter_vm_path/$1/;
        }

        # lowercase contact user id so that SSchapiro and sschapiro will show up as the same and not as two in the drop-down box.
        if ( exists( $VM->{$uuid}->{CUSTOMFIELDS}->{ Config( "vsphere", "contactuserid_field" ) } ) ) {
            $contact_user_id = lc( $VM->{$uuid}->{CUSTOMFIELDS}->{ Config( "vsphere", "contactuserid_field" ) } );
        }
    }
    print Tr(
              { 
                  -class => ( exists( $VM->{$uuid} ) ? 'vm_with_data' : 'vm_without_data' ), 
              },
              td [
                   a(
                       {
                          -href    => "vmdata.pl?uuid=$uuid",
                          -title   => "Details",
                          -onclick => "return false;",
                          -rel     => "vmdata.pl?uuid=$uuid",
                          -class   => "tip vmhostname"
                       },
                       $LAB->{HOSTS}->{$uuid}->{HOSTNAME}
                   ) . "\n".
                   a(
                       {
                          -href    => "vmscreenshot.pl?uuid=$uuid",
                          -title   => "Screenshot",
                          -onclick => "return false;",
                          -rel     => "vmscreenshot.pl?uuid=$uuid",
                          -class   => "tip"
                       },
                       img({-src => "lib/images/console_icon.png"})
                   ),
                   $display_vm_path,
                   $contact_user_id,
                   $expires,
              ]
    ) . "\n";
}
print <<EOF;
		</tbody>
		</table>
	</div>
EOF

my $conffiles = "<ol>\n\t<li>" . join( "</li>\n\t<li>", @CONFIGFILES ) . "</li>\n</ol>\n";
print <<EOF;
	<div id="tab-2">
		<p>The config files are 
		<code>
		$conffiles
		</code>
		and this is the <strong>merged</strong> result of all config files:</p>
		<pre>
EOF
$CONFIG{vsphere}{password} = "***** hidden *****" if ( Config( "vsphere", "password" ) );
my $confdump;
open( *CONFDUMP, ">", \$confdump ) or die "Could not open memory file: $!";
tied(%CONFIG)->OutputConfigToFileHandle(*CONFDUMP);
close(*CONFDUMP);
print escapeHTML($confdump);
print <<EOF;
		</pre>
	</div>
</div><!-- tabs -->
<hr/>
<div id="footer">
	<a href="https://github.com/ImmobilienScout24/lab-manager-light" target="_blank">Lab Manager Light</a> is licensed under the <a href="http://www.gnu.org/licenses/gpl.html" target="_blank">GNU General Public License</a>.
</div>
</body></html>
EOF

1;
