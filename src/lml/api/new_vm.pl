#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::Lab;
use JSON;

use User::pwent;

my $GECOS = {};    # cache for gecos lookups

my $C = new LML::Config();

my $LAB = new LML::Lab( $C->labfile );

my %result = (
);

# get a list of available host systems
sub hostFairness($) {
    # See https://www.vmware.com/support/developer/vc-sdk/visdk2xpubs/ReferenceGuide/vim.host.Summary.QuickStats.html
    # for an explanation of the Fairness values. As a first approximation we simply add the values here.
    my $h = shift;
    return 0 unless ( exists( $h->{stats} ) );
    my $hname    = $h->{name};
    my $fairness = ( abs( 1000 - $h->{stats}->{distributedCpuFairness} ) + abs( 1000 - $h->{stats}->{distributedMemoryFairness} ) ) / 2;
    Debug("Host Fairness for $hname is $fairness");
    return $fairness;
}

sub displayHost($) {
    # display ESX host together with CPU and MEM usage
    my $h = shift;
    return $h unless ( exists( $h->{stats} ) );
    return
      sprintf( "%s (%d GHz CPU, %d GB MEM used)",
               $h->{name},
               $h->{stats}->{overallCpuUsage} / 1024,
               $h->{stats}->{overallMemoryUsage} / 1024 );
}

# sorted list of hosts, fairest first. Fair means highest fairness (sort descending)
my @hosts = sort { hostFairness($b) <=> hostFairness($a) } $LAB->get_hosts;
Debug( "Sorted host list: " . join( ",", @hosts ) );


sub fill_hosts_json {
    my $vm_overview   = { hosts => [{value=>'auto_placement', label=>'auto_placement'}]};
        
        
    foreach my $host (@hosts) {
        my $host_info = {};
        $host_info->{value} = $host->{name};
        $host_info->{label} = displayHost($host);
        push @{$vm_overview->{hosts}}, $host_info;
    }

    return $vm_overview;
}



$result{create_new_vm} = fill_hosts_json();

print header('application/json');
print encode_json( \%result );
1;
