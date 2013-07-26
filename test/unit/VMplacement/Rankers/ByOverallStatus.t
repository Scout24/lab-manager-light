use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::VMplacement::Rankers::ByOverallStatus";
}

##################################
# test setup
###################################

my $obj = new_ok "LML::VMplacement::Rankers::ByOverallStatus" => [], "can create object";

is ( $obj->get_rank_value({status=>{overallStatus=>"green"}}), 100 , "green host ranked high");
is ( $obj->get_rank_value({status=>{overallStatus=>"yellow"}}), 0 , "yellow host ranked low");
throws_ok {$obj->get_rank_value({status=>{overallStatus=>"gaga"}})} qr(unknown overallStatus),"unknown status fails";
throws_ok {$obj->get_rank_value({})} qr(unknown overallStatus),"missing status fails";

done_testing();
