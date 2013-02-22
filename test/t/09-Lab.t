use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
    use_ok "LML::Config";
    use_ok "LML::Lab";
}

# load test config
my $C = new_ok( "LML::Config" => [ "src/lml/default.conf", "test/data/test.conf" ] );

# test if we can load config from config files
my $LAB = new_ok( "LML::Lab" => [ $C->labfile ], "should create new Lab object" );

is( $LAB->{HOSTS}{"4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"}{HOSTNAME}, "tsthst001", "LAB should contain hostname from test data" );
$LAB->set_filename("test/temp/new_lab.conf");
is ($LAB->write_file("test","test"),989,"should write 989 bytes");
dies_ok  { new LML::Lab("/dev/null") } "should die on reading invalid LAB file" ;
$LAB = new_ok(
               "LML::Lab" => [
                               {
                                 "HOSTS" => {
                                              "12345-1234-123" => {
                                                                    "HOSTNAME" => "foo",
                                                                    "MACS"     => [ "1:2:3", "4:5:6" ]
                                              }
                                 }
                               }
               ]
);

is_deeply(
           $LAB->get_host("12345-1234-123"),
           {
              "HOSTNAME" => "foo",
              "MACS"     => [ "1:2:3", "4:5:6" ]
           },
           "should return test data from previous test"
);

is( $LAB->get_host("foobar"), undef, "should return undef if VM not found" );
done_testing();
