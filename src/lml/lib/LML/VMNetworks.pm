use strict;
use warnings;

package LML::VMNetworks;

sub find_networks {
	my $host_name = shift;
	my $fallback_network = shift;
	my @all_networks = @_;

	 
	$host_name = substr($host_name, 0, -2);
	my @found_networks = grep(/$host_name/, @all_networks);
	unless (@found_networks) {
		@found_networks = grep(/$fallback_network/, @all_networks);
	}
	return @found_networks;
}

1;
