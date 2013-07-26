use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::Lab;
use LML::VMresources;
use Data::Dumper;

BEGIN {
    use_ok "LML::VMplacement";
}

##################################
# test setup
###################################

my @truefilter_params;

sub truefilter::host_can_vm {
    my ( $self, $host, $vm ) = @truefilter_params = @_;
    return 1;
}
my $truefilter = bless( {}, "truefilter" );

sub falsefilter::host_can_vm {
    my ( $self, $host, $vm ) = @_;
    return 0;
}
my $falsefilter = bless( {}, "falsefilter" );

my @rankerparms;

sub testranker::get_rank_value {
    my ( $self, $host ) = @rankerparms = @_;
    return 1;
}
my $testranker = bless( {}, "testranker" );

my $test_host_1 = {
                    id         => "id-1",
                    networks   => ["network-1"],
                    datastores => ["datastore-1"],
};

my $test_host_2 = {
                    id         => "id-2",
                    networks   => ["network-2"],
                    datastores => ["datastore-2"],
};

my $simple_lab_with_one_host = new LML::Lab( { "ESXHOSTS" => { "id-1" => $test_host_1 } } );
my $simple_lab_with_two_hosts = new LML::Lab( { "ESXHOSTS" => { "id-1" => $test_host_1, "id-2" => $test_host_2 } } );

##################################
# test cases
###################################

{
    my $obj = new LML::VMplacement($simple_lab_with_one_host);
    throws_ok { $obj->get_recommendations("foobar") } qr(LML::VMresources), "should die if arg is not LML::VMresources";
}
{
    my $obj    = new LML::VMplacement($simple_lab_with_one_host);
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply(
               [@rec],
               [
                  {
                     id         => "id-1",
                     datastores => [],
                  }
               ],
               "should return recommendation from sample data in expected format"
    );
}

{
    my $obj    = new LML::VMplacement( $simple_lab_with_two_hosts, [$truefilter], [$testranker] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( \@truefilter_params, [ $truefilter, $test_host_2, $vm_res ], "test filter was called with correct parms" );  
    is_deeply( \@rankerparms, [ $testranker, $test_host_2 ], "test ranker was called with correct parms" );
}

{
    my $obj    = new LML::VMplacement( $simple_lab_with_one_host, [ $truefilter, $falsefilter ] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [], "should return no recommendation as one filter is always false" );
}


done_testing();
