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

dies_ok { $LAB->remove } "should be not ok to not specify uuid on host removal";
ok( $LAB->remove("haha"),                                 "should be ok to remove non-existant host" );
ok( $LAB->remove('12345-1234-123'), "should be ok to remove existing host" );

done_testing();
