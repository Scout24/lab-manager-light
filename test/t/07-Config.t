use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok "LML::Config";
}

# test if we can load the class
my $C = new_ok( "LML::Config" => [ "src/lml/default.conf", "test/data/test.conf" ] );

# now test the get method
my $test_data = $C->get('dhcp', 'hostsfile');
ok($test_data, "Should fail, if no value for hostsfile was read");

done_testing();
