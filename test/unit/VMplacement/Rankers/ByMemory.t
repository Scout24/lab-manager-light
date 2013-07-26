use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::VMplacement::Rankers::ByMemory";
}

##################################
# test setup
###################################

my $obj = new_ok "LML::VMplacement::Rankers::ByMemory" => [], "can create object";

is ( $obj->get_rank_value({hardware=>{memorySize=>20000},stats=>{overallMemoryUsage => 5000}}), 75 , "returns free memory in percent");
throws_ok {$obj->get_rank_value({})} qr(missing data),"missing data fails";


done_testing();
