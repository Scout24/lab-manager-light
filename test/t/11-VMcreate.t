use Test::More tests => 7;
use LML::Config;

BEGIN {
    use_ok "LML::VMNetworks";
}

my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

my $fallback_network = $C->get("network_policy", "catchall");
my @all_networks = ("1_BE_devweb", "2_BE_devgac", "1_FE_devweb", "3_FE_beryum", $fallback_network);

# should find correct networks
my @networks = LML::VMNetworks::find_networks("devweb03", $fallback_network, @all_networks);
ok(scalar(@networks) == 2, "Should find networks for devweb03"); 
ok(scalar(grep(/1_BE_devweb/, @networks)) == 1, "Should find 1_BE_devweb");
ok(scalar(grep(/1_FE_devweb/, @networks)) == 1, "Should find 1_FE_devweb");

# should find the fallback network
my @networks = LML::VMNetworks::find_networks("devabc01", $fallback_network, @all_networks);
ok(scalar(@networks) == 1, "Should find networks for devabc");
ok($networks[0] eq $fallback_network, "Should find the fallback network");

# should not find any networks
my @networks = LML::VMNetworks::find_networks("devxyz01", $fallback_network, ("1_BE_devweb", "2_BE_devgac", "1_FE_devweb", "3_FE_beryum"));
ok(scalar(@networks) == 0, "Should not find any networks");
