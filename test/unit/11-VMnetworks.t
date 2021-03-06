use strict;
no warnings 'redefine';

use Test::More;
use LML::Config;
use Data::Dumper;

BEGIN {
    use_ok "LML::VMnetworks";
}


my $test_config = new LML::Config(
    {
       "new_vm" => {
                     "network_search_order" => [ "DEVNIC_STATIC", "DEVNIC_DYNAMIC" ],
                     "2nd_interface_suffix" => "_FE",
                     "2nd_interface"        => [".*web.*"]
       },
       "network_assignment" => { "devnic_static" => ["^devlts.*","^devweb.*"], "devnic_dynamic" => ["^dev.*"] }
    }
);

my $vm_networks = new_ok( "LML::VMnetworks" => [$test_config], "should create" );


my @network_labels = $vm_networks->find_network_labels("otherNoMatch01");
is_deeply( \@network_labels, [], "should return no net" );

@network_labels = $vm_networks->find_network_labels("devlts01");
is_deeply( \@network_labels, ["DEVNIC_STATIC"], "should return static net" );

@network_labels = $vm_networks->find_network_labels("devxxx01");
is_deeply( \@network_labels, ["DEVNIC_DYNAMIC"], "should return dynamic net" );

@network_labels = $vm_networks->find_network_labels("devweb01");
is_deeply( \@network_labels, ["DEVNIC_STATIC", "DEVNIC_STATIC_FE"], "should return static and fe network" );

@network_labels = $vm_networks->find_network_labels("devweb01");
is_deeply( \@network_labels, ["DEVNIC_STATIC", "DEVNIC_STATIC_FE"], "should return static and fe network" );


done_testing();
