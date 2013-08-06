#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../../lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::Lab;
use JSON;
use Data::Dumper;
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



sub fill_host_overview_json {
    my $vm_overview   = { hosts => []};
        
        
    foreach my $host (@hosts) {
        my $host_info = {};
        my @networks = $LAB->get_network_names($host->{"networks"});
        my @datastores = $LAB->get_datastore_names($host->{"datastores"});
        $host_info->{name} =  $host->{name};
        $host_info->{id} =  $host->{id};
        $host_info->{overallStatus} =  $host->{status}->{overallStatus};
        $host_info->{cpuUsage} =  sprintf( "%.2f / %.0f", $host->{stats}->{overallCpuUsage} / 1024, $host->{hardware}->{totalCpuMhz} / 1024 );
        $host_info->{memoryUsage} =  sprintf("%.2f / %.0f", $host->{stats}->{overallMemoryUsage} / 1024, $host->{hardware}->{memorySize} / 1024);
        $host_info->{fairness} = hostFairness($host);
        $host_info->{networks} =  \@networks;
        $host_info->{datastores} =  \@datastores ;
        $host_info->{hardware} = $host->{hardware}->{vendor} . " " . $host->{hardware}->{model};
        $host_info->{product} =  $host->{product}->{fullName};
            
      
        push @{$vm_overview->{hosts}}, $host_info;
    }

    return $vm_overview;
}



$result{host_overview_json} = fill_host_overview_json();
   
print header('application/json');
print encode_json( \%result );
1;
