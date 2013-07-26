use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::VMresources;
use LML::Lab;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByNetworkLabel";
}

##################################
# test setup
###################################

my $test_host_1 = {
    id       => "id-1",
    networks => [ "network-1", "network-2" ],
    # other attributes are unimportant
};

my $lab = new LML::Lab(
    {
       "NETWORKS" => {
           "network-1" => {
               "hosts" => [
                            "id-1"
               ],
               "id"   => "network-1",
               "name" => "NETWORK LABEL 1"
           },
           "network-2" => {
               "hosts" => [
                            "id-2"
               ],
               "id"   => "network-2",
               "name" => "NETWORK LABEL 2"
           },
       }
    }
);
my $vm_res;

##################################
# test cases
###################################

new_ok( "LML::VMplacement::Filters::ByNetworkLabel" => [$lab] );
throws_ok { new LML::VMplacement::Filters::ByNetworkLabel( {} ) } qr(must be an instance of LML::Lab), "dies on value for lab is not defined";

my $filter = new LML::VMplacement::Filters::ByNetworkLabel($lab);

$vm_res = new LML::VMresources( { networks => [] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 1, "should return true(1) when vm_res don't requires a network" );

$vm_res = new LML::VMresources( { networks => ['NETWORK LABEL 1'] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 1, "should return true(1) when host provides all required network" );

$vm_res = new LML::VMresources( { networks => ['NETWORK LABEL 2'] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 1, "should return true(1) when host provides all required network" );

$vm_res = new LML::VMresources( { networks => ['NETWORK LABEL 1', 'NETWORK LABEL 2'] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 1, "should return true(1) when host provides all required networks" );

$vm_res = new LML::VMresources( { networks => ['NETWORK LABEL 2', 'NETWORK LABEL 1'] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 1, "should return true(1) when host provides all required networks" );

$vm_res = new LML::VMresources( { networks => ['NETWORK LABEL 3'] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 0, "should return false(0) when host not provides all required networks" );

$vm_res = new LML::VMresources( { networks => ['NETWORK LABEL 1','NETWORK LABEL 3'] } );
is( $filter->host_can_vm( $test_host_1, $vm_res ), 0, "should return false(0) when host not provides all required networks" );


done_testing();
