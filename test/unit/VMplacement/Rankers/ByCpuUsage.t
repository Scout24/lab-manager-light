use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::VMplacement::Rankers::ByCpuUsage";
}

##################################
# test setup
###################################

my $obj = new_ok "LML::VMplacement::Rankers::ByCpuUsage" => [], "can create object";

is ( $obj->get_rank_value({stats=>{overallCpuUsage=>500},hardware=>{totalCpuMhz => 2000}}), 75 , "returns free cpu in percent");
throws_ok {$obj->get_rank_value({status=>{overallStatus=>"gaga"}})} qr(missing data),"missing data fails";


done_testing();
