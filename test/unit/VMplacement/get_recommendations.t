use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::Lab;
use LML::VMresources;
use LML::Config;

BEGIN {
    use_ok "LML::VMplacement";
}

##################################
# test setup
###################################

my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

my @truefilter_params;

my $test_host_1 = {
                    id         => "id-1",
                    networks   => ["network-1"],
                    datastores => ["datastore-1"],
                    stats      => {
                               "overallCpuUsage"    => 1,
                               "overallMemoryUsage" => 6
                    },
};

my $test_host_2 = {
                    id         => "id-2",
                    networks   => ["network-2"],
                    datastores => ["datastore-2"],
                    stats      => {
                               "overallCpuUsage"    => 3,
                               "overallMemoryUsage" => 5
                    },
};

my $test_host_3 = {
                    id         => "id-3",
                    networks   => ["network-3"],
                    datastores => ["datastore-3"],
                    stats      => {
                               "overallCpuUsage"    => 5,
                               "overallMemoryUsage" => 1
                    },
};

sub truefilter::host_can_vm {
    my ( $self, $host, $vm ) = @_;
    if ( $host->{id} eq "id-1" ) {
        @truefilter_params = @_;    # remember only test_host_1, because the filter get called with hosts in random order
    }
    return 1;
}
sub truefilter::get_name {
    return "truefilter";
}
my $truefilter = bless( {}, "truefilter" );

sub falsefilter::host_can_vm {
    my ( $self, $host, $vm ) = @_;
    return 0;
}
sub falsefilter::get_name {
    return "falsefilter";
}
my $falsefilter = bless( {}, "falsefilter" );

my @rankerparms;

sub testranker::get_rank_value {
    my ( $self, $host ) = @_;
    if ( $host->{id} eq "id-1" ) {
        @rankerparms = @_;    # remember only test_host_1, because the filter get called with hosts in random order
    }
    return 1;
}

sub testranker::get_name {
    return "test_ranker";
}
my $testranker = bless( {}, "testranker" );

sub testranker_by_ram::get_rank_value {
    my ( $self, $host ) = @rankerparms = @_;
    return $host->{stats}->{overallMemoryUsage};
}
sub testranker_by_ram::get_name {
    return "testranker_by_ram";
}
my $testranker_by_ram = bless( {}, "testranker_by_ram" );

sub testranker_by_cpu::get_rank_value {
    my ( $self, $host ) =  @_;
    return $host->{stats}->{overallCpuUsage};
}
sub testranker_by_cpu::get_name {
    return "testranker_by_cpu";
}
my $testranker_by_cpu = bless( {}, "testranker_by_cpu" );

my $simple_lab_with_one_host = new LML::Lab( { "ESXHOSTS" => { $test_host_1->{id} => $test_host_1 } } );
my $simple_lab_with_three_hosts = new LML::Lab( { "ESXHOSTS" => { $test_host_1->{id} => $test_host_1, $test_host_2->{id} => $test_host_2, $test_host_3->{id} => $test_host_3 } } );

##################################
# test cases
###################################

# validate function parameters
{
    my $obj = new LML::VMplacement($C,$simple_lab_with_one_host,[],[]);
    throws_ok { $obj->get_recommendations("foobar") } qr(LML::VMresources), "should die if arg is not LML::VMresources";
}

# validate the format of the return value
{
    my $obj    = new LML::VMplacement($C,$simple_lab_with_one_host,[],[]);
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

# validate the arguments which are passed to filters and rankers (implicit testing of the truefilter too)
{
    my $obj    = new LML::VMplacement($C, $simple_lab_with_three_hosts, [$truefilter], [$testranker] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( \@truefilter_params, [ $truefilter, $test_host_1, $vm_res ], "test filter was called with correct parms" );
    is_deeply( \@rankerparms, [ $testranker, $test_host_1 ], "test ranker was called with correct parms" );
}

# validate the filtering
{
    my $obj    = new LML::VMplacement($C, $simple_lab_with_one_host, [ $truefilter, $falsefilter ],[] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [], "should return no recommendation as one filter is always false" );
}

# validate the ranking by a single mocked ram filter
{
    my $obj    = new LML::VMplacement($C, $simple_lab_with_three_hosts, [$truefilter], [$testranker_by_ram] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [ { id => "id-1", datastores => [], }, { id => "id-2", datastores => [], }, { id => "id-3", datastores => [], } ], "should return hosts in descending order by ram" );
}


# validate the ranking by a single mocked cpu ranker
{
    my $obj    = new LML::VMplacement($C, $simple_lab_with_three_hosts, [$truefilter], [$testranker_by_cpu] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [ { id => "id-3", datastores => [], }, { id => "id-2", datastores => [], }, { id => "id-1", datastores => [], } ], "should return hosts in descending order by cpu" );
}


# validate the ranking by a mocked ram and a mocked cpu ranker
{
    my $obj    = new LML::VMplacement($C, $simple_lab_with_three_hosts, [$truefilter], [$testranker_by_ram,$testranker_by_cpu] );
    my $vm_res = new LML::VMresources();
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [ { id => "id-2", datastores => [], }, { id => "id-1", datastores => [], }, { id => "id-3", datastores => [], } ], "should return hosts in descending order by cpu+ram " );
}


# validate the ranking by a mocked ram and a mocked cpu ranker
{
    my $obj    = new LML::VMplacement($C, $simple_lab_with_one_host,[],[] );
    my $vm_res = new LML::VMresources({disks=>[{size=>2},{size=>2}]});
    my @rec    = $obj->get_recommendations($vm_res);
    is_deeply( [@rec], [ { id => "id-1", datastores => ['datastore-1','datastore-1'], } ], "should return the first datastore of suitable host for every required disk" );
}


done_testing();
