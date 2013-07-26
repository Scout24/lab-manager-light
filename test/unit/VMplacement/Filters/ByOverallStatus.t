use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByOverallStatus";
}

##################################
# test setup
###################################

my $obj = new_ok "LML::VMplacement::Filters::ByOverallStatus" => [], "can create object";

ok ( $obj->host_can_vm({status=>{overallStatus=>"green"}}), "green host is OK");
ok ( $obj->host_can_vm({status=>{overallStatus=>"yellow"}}), "yellow host is OK");
ok ( ! $obj->host_can_vm({status=>{overallStatus=>"red"}}), "red host is not OK");
ok ( ! $obj->host_can_vm({status=>{overallStatus=>"grey"}}), "grey host is not OK");
throws_ok { $obj->host_can_vm({}) } qr(unknown status), "host without status fails";

done_testing();
