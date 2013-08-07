use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByActive";
}

##################################
# test setup
###################################

my $obj = new_ok "LML::VMplacement::Filters::ByActive" => [], "can create object";

is ($obj->get_name,"ByActive","return module name");
ok ( $obj->host_can_vm({status=>{active => "1"}}), "active host is OK");
ok ( ! $obj->host_can_vm({status=>{active=>""}}), "not active host is not OK");

throws_ok { $obj->host_can_vm({}) } qr(unknown status), "host without status fails";

done_testing();
