use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::VMresources;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByMemory";
}

##################################
# test setup
###################################

my $obj = new_ok "LML::VMplacement::Filters::ByMemory" => [], "can create object";

ok ( $obj->host_can_vm({hardware=>{memorySize=>"10000"},stats=>{overallMemoryUsage => 5000}},new LML::VMresources({ram=>2000})), "VM fits on host");
ok ( ! $obj->host_can_vm({hardware=>{memorySize=>"10000"},stats=>{overallMemoryUsage => 5000},name=>"foo"},new LML::VMresources({ram=>20000})), "VM does not fit on host");

throws_ok { $obj->host_can_vm({}) } qr(missing data), "host without data fails";

done_testing();
