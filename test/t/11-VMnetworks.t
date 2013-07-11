use strict;
use warnings;

use Test::Simple tests => 19;

use LML::VMnetworks;

my $spec = {};

my $net_123_BE_devweb = {
    "name" => "123_BE_devweb",
    "spec" => $spec
};

my $net_123_FE_devweb = {
    "name" => "123_FE_devweb",
    "spec" => {}
};

my $net_456_BE_devweb = {
    "name" => "456_BE_devweb",
    "spec" => {}
};

my $net_456_FE_devweb = {
    "name" => "456_FE_devweb",
    "spec" => {}
};


my $result = LML::VMnetworks::is_backend($net_123_BE_devweb);
ok($result == 1, "123_BE_devweb is backend");
$result = LML::VMnetworks::is_backend($net_123_FE_devweb);
ok($result == 0, "123_FE_devweb is not backend");

$result = LML::VMnetworks::compare($net_123_FE_devweb, $net_123_BE_devweb);
ok($result == 1, "123_FE_devweb > 234_BE_devweb");
$result = LML::VMnetworks::compare($net_123_FE_devweb, $net_123_FE_devweb);
ok($result == 0, "123_FE_devweb == 123_FE_devweb");
$result = LML::VMnetworks::compare($net_123_BE_devweb, $net_123_BE_devweb);
ok($result == 0, "123_BE_devweb == 123_BE_devweb");
$result = LML::VMnetworks::compare($net_123_BE_devweb, $net_123_FE_devweb);
ok($result == -1, "234_BE_devweb < 123_FE_devweb");

my @result = LML::VMnetworks::sort_networks($net_123_BE_devweb, $net_123_FE_devweb);
ok($result[0] == $net_123_BE_devweb, "shouldn't change already sorted: $result[0] eq 123_BE_devweb");
ok($result[1] == $net_123_FE_devweb, "shouldn't change already sorted:  $result[1] eq 234_FE_devweb");

@result = LML::VMnetworks::sort_networks($net_123_FE_devweb, $net_123_BE_devweb);
ok($result[0] == $net_123_BE_devweb, "should sort simple: $result[0] eq 234_BE_devweb");
ok($result[1] == $net_123_FE_devweb,  "should sort simple: $result[1] eq 123_FE_devweb");

@result = LML::VMnetworks::sort_networks($net_456_FE_devweb, $net_123_BE_devweb, $net_456_BE_devweb, $net_123_FE_devweb);
ok(($result[0] or $result[1]  == $net_123_BE_devweb), "should sort many: $result[0] ~~ /.+BE.+/");
ok(($result[0] or $result[1] == $net_456_BE_devweb), "should sort many: $result[1] ~~ /.+BE.+/");
ok($result[0] != $result[1], "should sort many: $result[0] ne $result[1]");
ok(($result[2] or $result[3] == $net_123_FE_devweb), "should sort many: $result[2] ~~ /.+FE.+/");
ok(($result[2] or $result[3] == $net_456_FE_devweb), "should sort many: $result[3] ~~ /.+FE.+/");
ok($result[2] != $result[3], "should sort many: $result[2] ne $result[3]");

my %wrapped = LML::VMnetworks::wrap_network_spec_for_sorting($spec, "123_BE_devweb");
ok($wrapped{"name"} eq "123_BE_devweb", "should wrap a network spec");
ok($wrapped{"spec"} eq $spec, "should wrap a network spec");

$result = LML::VMnetworks::unwrap_network_spec($net_123_BE_devweb);
ok($result == $spec, "should unwrap a network spec");
