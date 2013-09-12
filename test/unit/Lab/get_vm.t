use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Exception;

use Data::Dumper;

use LML::Lab;
# we use the following here to mock it, it is basically only used within Lab
use LML::VMware;

my $mock            = new Test::MockModule('LML::VMware');
$mock->mock(
    get_vm_data =>
    sub {
        # always return nothing in mock
        return \();
    } );
use LML::VM;


my $LAB = new LML::Lab( {
                          "HOSTS" => {
                                       "12345-1234-123" => {
                                                             "HOSTNAME" => "foo",
                                                             "MACS"     => [ "1:2:3", "4:5:6" ] } } } );

is_deeply(
           $LAB->get_vm("12345-1234-123"),
           {
              "HOSTNAME" => "foo",
              "NAME"     => "foo",
              "MACS"     => [ "1:2:3", "4:5:6" ],
           },
           "should return test data from previous test"
);

is( $LAB->get_vm("foobar"), undef, "should return undef if VM not found" );
done_testing();
