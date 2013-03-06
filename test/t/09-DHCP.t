use strict;
use warnings;

use File::Slurp;
use Test::More;
use Test::Warn;
use LML::Common;
use LML::Config;
use LML::Lab;
BEGIN {
    use_ok "LML::DHCP";
}

my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

my $dhcpconf = $C->get( "dhcp", "hostsfile" );
ok( $dhcpconf, "dhcp hostsfile is set" );
ok ( -r $C->labfile, "LAB file is set and readable");
ok( $C->get( "dhcp", "triggercommand" ), "dhcp triggercommand is set" );

# test writing out dhcp config
# the following corresponds to $LAB_TESTDATA in 00-Common.t
# NOTE: lines indented with TABs not SPACEs!!!
my $expected_dhcp_hosts = <<EOF;
host 4213038e-9203-3a2b-ce9d-c6dac1f2dbbf { 
	hardware ethernet 01:02:03:04:6e:4e;
	option host-name "tsthst001.arc.int";
	ddns-hostname "tsthst001";
	fixed-address 1.2.3.4;
	option foo "bar";
	option bar baz;
}

host 4213059e-70c2-6f34-1986-50463d0222f8 { 
	hardware ethernet 01:02:03:04:69:b0;
	option host-name "tstgag002.arc.int";
	ddns-hostname "tstgag002";
	option foo2 "bar2";
}

EOF

# read data file created from $LAB_TESTDATA in 00-Common.t
my $LAB    = new LML::Lab($C->labfile);
my @errors = LML::DHCP::UpdateDHCP( $C, $LAB );
ok( scalar(@errors) == 0, "create dhcp hosts file" );
is( $expected_dhcp_hosts, read_file($dhcpconf), "dhcp hosts file matches test data" );
ok( -r "test/temp/triggercommand.txt", "dhcp triggercommand ran" );

# negative test for triggercommand
$CONFIG{"dhcp"}{"triggercommand"} = "false";
warning_like  { @errors = LML::DHCP::UpdateDHCP( $C,$LAB ) } qr(trigger command), "warn if trigger command failes" ;
is( $errors[0], "Could not trigger DHCP server, please call for help", "dhcp triggercommand false failed" );
done_testing;
