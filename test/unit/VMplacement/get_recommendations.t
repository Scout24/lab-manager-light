use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::Lab;
use LML::VMresources;

BEGIN {
    use_ok "LML::VMplacement";
}

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
    diag("testranker called");
    return 1;
}
my $testranker = bless( {}, "testranker" );

my $test_host = {
                  id         => "id-1",
                  networks   => ["network-1"],
                  datastores => ["datastore-1"],
};
my $simple_lab = new LML::Lab( { "ESXHOSTS" => { "id-1" => $test_host } } );

{
    my $obj = new LML::VMplacement($simple_lab);
    throws_ok { $obj->get_recommendations("foobar") } qr(LML::VMresources), "should die if arg is not LML::VMresources";

}
{
    my $obj    = new LML::VMplacement($simple_lab);
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply(
               [@rec],
               [ {
                     id         => "id-1",
                     datastores => [],
                  }
               ],
               "should return recommendation from sample data in expected format"
    );
}

{
    my $obj    = new LML::VMplacement( $simple_lab, [$truefilter], [$testranker] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( \@truefilter_params, [ $truefilter, $test_host, $vm_res ], "test filter was called with correct parms" );
    is_deeply( \@rankerparms, [ $testranker, $test_host], "test ranker was called with correct parms" );
}

{

    my $obj    = new LML::VMplacement( $simple_lab, [ $truefilter, $falsefilter ] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [], "should return no recommendation as one filter is always false" );
}
done_testing();
