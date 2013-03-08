#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::Lab;

use User::pwent;

my $GECOS = {};    # cache for gecos lookups
# get full name of userid
sub get_gecos {
    my ($userid) = @_;
    return "" unless ($userid);
    Debug "Looking up $userid";
    if ( not exists $GECOS->{$userid} ) {
        if ( my $pwnam = getpwnam($userid) ) {
            $GECOS->{$userid} = $pwnam->gecos;
        } else {
            $GECOS->{$userid} = "Could not lookup user";
        }
        Debug "Caching $userid = " . $GECOS->{$userid};
    }
    return $GECOS->{$userid};
}

my $C = new LML::Config();

my $LAB = new LML::Lab( $C->labfile );

print header();
print start_html(
                  -title  => $C->get( "vsphere", "server" ) . " Lab Manager Light",
                  -script => [
                               { -src => "lib/js/jquery-1.8.3.min.js" },
                               { -src => "lib/js/jquery.cluetip.min.js" },
                               { -src => "lib/js/jquery.tabsLite.js" },
                               { -src => "lib/js/jquery.dataTables.min.js" },
                               { -src => "lib/js/TableTools.min.js" },
                               { -src => "lib/js/lml.js" },
                  ],
                  -style => [
                              { -src   => "lib/css/jquery.cluetip.css", },
                              { -src   => "lib/css/jquery.dataTables.css", },
                              { -src   => "lib/css/TableTools.css", },
                              { -src   => "lib/css/lml.css", },
                              { -media => "print", -src => "lib/css/lml-print.css" },
                  ] );

print <<EOF;
<div id="logoframe">
    <a href="#"><img src="lib/images/LabManagerLightlogo-small.png"/></a><br/>
</div>
&nbsp;
<div id="tabs">
    <ul>
        <li><a href="#overview">VM Overview</a></li>
        <li><a href="#new">New VM</a></li>
        <li><a href="#tools">Tools</a></li>
        <li><a href="#config">Configuration</a></li>
    </ul>
EOF

print <<EOF;
	<div id="overview">
        <table id="vmlist_table" cellpadding="3" cellspacing="0">
EOF

print thead(
             { -id => "vmlist" },
             Tr(
                 { -valign => "top" },
                 th( { -title => "Click to sort" }, 'Hostname' ),
                 th( { -title => "Click to sort" }, "VM Path" ),
                 th( { -title => "Click to sort" }, "Contact User ID" ),
                 th( { -title => "Click to sort" }, "Expires" ),
                 th( { -title => "Click to sort" }, "ESX Host" ),
             ) ) . "\n\n\t\t<tbody>\n";

my $display_filter_vm_path = $C->get( "gui",     "display_filter_vm_path" );
my $contactuser_field      = $C->get( "vsphere", "contactuserid_field" );
my $expires_field          = $C->get( "vsphere", "expires_field" );

while ( my ( $uuid, $VM ) = each %{ $LAB->{HOSTS} } ) {
    Debug( "Handling " . Data::Dumper->Dump( [$VM] ) );
    next unless ( exists $VM->{UUID} );
    my $expires         = "unknown";
    my $contact_user_id = "unknown";
    my $display_vm_path = "<em>(no data available)</em>";
    my $esxhost         = "unknown";
    if ( $expires_field and exists $VM->{CUSTOMFIELDS}->{$expires_field} ) {
        eval {
            $expires =
              DateTime::Format::Flexible->parse_datetime( $VM->{CUSTOMFIELDS}->{$expires_field},
                                              european => ( $C->get( "vsphere", "expires_european" ) ? 1 : 0 ) )->ymd();
        };
    }
    if ( exists $VM->{PATH} ) {
        $display_vm_path = $VM->{PATH};

        if ($display_filter_vm_path) {
            $display_vm_path =~ s/$display_filter_vm_path/$1/;
        }
    }

    if ( exists $VM->{HOST} ) {
        $esxhost = $VM->{HOST};
    }

# lowercase contact user id so that SSchapiro and sschapiro will show up as the same and not as two in the drop-down box.
    if ( $contactuser_field and exists( $VM->{CUSTOMFIELDS}->{$contactuser_field} ) ) {
        $contact_user_id = lc( $VM->{CUSTOMFIELDS}->{$contactuser_field} );
    }
    my $screenshot_url = "vmscreenshot.pl?stream=1;uuid=$uuid";
    print Tr(
              td [
                   a( {
                        -href    => "vmdata.pl/$uuid",
                        -title   => "Details",
                        -onclick => "return false;",
                        -rel     => "vmdata.pl/$uuid",
                        -class   => "tip vmhostname"
                      },
                      $VM->{HOSTNAME} )
                     . "\n"
                     . a( {
                            -href    => $screenshot_url,
                            -title   => "Screenshot",
                            -onclick => "return false;",
                            -rel     => $screenshot_url,
                            -class   => "tip"
                          },
                          img( { -src => "lib/images/console_icon.png" } )
                     ),
                   $display_vm_path,
                   span( { -title => get_gecos($contact_user_id) }, $contact_user_id ),
                   $expires, $esxhost
              ] ) . "\n\n";
}
print <<EOF;

        </tbody></table>
	</div>
	<div class="main_content" id="new">
	   <p>Coming soon... (Help wanted!)</p>
	</div>
	
	<div class="main_content" id="tools">
       <p>
            <span id="clear_button" class="button" title="Clear tool output">Clear</span>
            <a id="hostdatetime_button" class="button" href="hostdatetime.pl" title="vSphere Time Sync Check">vSphere Time Sync Check</a>
            <a id="license_button" class="button" href="LICENSE.TXT" title="Software License">Software License</a>
       </p>
       <fieldset id="tools_frame"><legend id="tools_title"></legend>
            <div id="tools_content">
            </div>
       </fieldset>
    </div>
EOF

my $conffiles = "<ol>\n\t<li>" . join( "</li>\n\t<li>", @CONFIGFILES ) . "</li>\n</ol>\n";
print <<EOF;
	<div class="main_content" id="config">
		<p>The config files are 
		<code>
		$conffiles
		</code>
		and this is the <strong>merged</strong> result of all config files:</p>
		<pre>
EOF
# mask password in config dump
$C->set( "vsphere", "password", "***** hidden *****" ) if ( $C->get( "vsphere", "password" ) );
my $confdump;
open( *CONFDUMP, ">", \$confdump ) or die "Could not open memory file: $!";
tied(%CONFIG)->OutputConfigToFileHandle(*CONFDUMP);
close(*CONFDUMP);
print escapeHTML($confdump);

print <<EOF;
		</pre>
	</div>
</div><!-- tabs -->

<div id="footer">
	<a href="https://github.com/ImmobilienScout24/lab-manager-light" target="_blank">Lab Manager Light</a> is licensed under the <a href="http://www.gnu.org/licenses/gpl.html" target="_blank">GNU General Public License</a>.
	Version $LML_VERSION
</div>
</body></html>
EOF

1;
