use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::Lab;
use LML::VMresources;
use LML::Config;
use Clone qw(clone);

BEGIN {
    use_ok "LML::VMplacement";
}

##################################
# test setup
#
# This scenario test should describe the how the default filters and rankers affect the placement to a given VMresources instance.
#
# In general a filter describe a lower bound a host must fulfill. In most cases the filter uses the current value which might be calculated.
# Filters can be chained -> the order of the applied filter should not matter.
#
# The filter ByMemory uses  $host->{hardware}->{memorySize} - $host->{stats}->{overallMemoryUsage}) as a lower bound.
# The filter ByActive uses  $host->{status} => { active => "1" } as a lower bound.
# The filter ByOverallStatus uses  $host->{status} => { overallStatus => "yellow|green" } as a lower bound.
# The filter ByNetworkLabel uses the $host->{networks} where all required networks must be supported by this host as a lower bound.
#
#
# In general a ranker returns a number for a current data view (e.g. free RAM) which might be positive or even negativ.
# A ranker get usally list of hosts which is already filtered by the filters (see above).
# It's not like a filter which asserts only a lower bound, it is rating where the host with the highest returned number will be rated
# before other hosts with a low numbers. In other words: the host with the highest rating will be choosen for the placement.
#
# Ranker can be chained -> at the moment all returned rating numbers will be simply accumulated.
#
# The ranker ByCpuUsage returns free cpu in percent which could be a number between 0 and 100.
# The ranker ByMemory returns free memory in percent whi10ch could be a number between 0 and 100.
# The ranker ByOverAllStatus returns 100 for a green overallStatus and 0 for a yellow overallStatus.
#
###################################

my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

my @truefilter_params;

my $test_host_1 = {
    id         => "id-1",
    networks   => ["network-1"],
    datastores => ["datastore-1"],
    stats      => {
        "overallCpuUsage" =>
          800,    # this means 60% free cpu (at least 1600 cpu still available) - this is currently no filter criteria only for ranking
        "overallMemoryUsage" => 18000    # this means 10% free ram (at least 2000 MB still available)
    },
    hardware => {
                  memorySize  => 20000,
                  totalCpuMhz => 2000
    },
    status => {
                overallStatus => "yellow",
                active        => "1",
    },
    vms  => ["vm-1-of-group-foo"],
    name => 'host_id-1',

};

my $test_host_2 = {
    id         => "id-2",
    networks   => [ "network-1", "network-2" ],
    datastores => ["datastore-2"],
    stats      => {
        "overallCpuUsage" =>
          1000,    # this means 50% free cpu (at least 1000 cpu still available) - this is currently no filter criteria only for ranking
        "overallMemoryUsage" => 14000    # this means 30% free ram (at least 6000 MB still available)
    },
    hardware => {
                  memorySize  => 20000,
                  totalCpuMhz => 2000
    },
    status => {
                overallStatus => "yellow",
                active        => "1"
    },
    vms  => [],
    name => 'host_id-2',
};

my $test_host_3 = {
    id         => "id-3",
    networks   => [ "network-1", "network-2", "network-3" ],
    datastores => ["datastore-3"],
    stats      => {
        "overallCpuUsage" =>
          1800,    # this means 10% free cpu (at least 200 cpu still available) - this is currently no filter criteria only for ranking
        "overallMemoryUsage" => 10000    # this means 50% free ram (at least 10000 MB still available)
    },
    hardware => {
                  memorySize  => 20000,
                  totalCpuMhz => 2000
    },
    status => {
                overallStatus => "yellow",
                active        => "1"
    },
    vms  => [],
    name => 'host_id-3',
};

# the Lab config should be consistent, that means the hosts in the NETWORKS section must be fit to the host definition
my $simple_lab_with_three_hosts = new LML::Lab( {
       "ESXHOSTS" => { $test_host_1->{id} => $test_host_1, $test_host_2->{id} => $test_host_2, $test_host_3->{id} => $test_host_3 },
       "NETWORKS" => {
                       "network-1" => {
                                        "hosts" => [ $test_host_1->{id} ],
                                        "id"    => "network-1",
                                        "name"  => "NETWORK LABEL 1"
                       },
                       "network-2" => {
                                        "hosts" => [ $test_host_1->{id}, $test_host_2->{id} ],
                                        "id"    => "network-2",
                                        "name"  => "NETWORK LABEL 2"
                       },
                       "network-3" => {
                                        "hosts" => [ $test_host_1->{id}, $test_host_2->{id}, $test_host_3->{id} ],
                                        "id"    => "network-3",
                                        "name"  => "NETWORK LABEL 3"
                       },
       },
       "HOSTS" => {
           "1234545-2344-222-2344-9898239874" => {
                                                   "NAME"  => "foobar23",           # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-1-of-group-foo"
           },
       },
    } );

##################################
# scenario test cases
##################################

my $vm_placement = new_ok( "LML::VMplacement" => [ $C, $simple_lab_with_three_hosts ],"test builtin filter initialization" );

# validate the ranking and filtering for the given scenario, where the requirements are all fulfilled (no hosts should be filtered)
{
    my $vm_res = new LML::VMresources( {
          ram      => 1000,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 1'],      # all hosts support this network
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'                # the config defines no group_pattern, so this will be not a filter criteria
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 3, "No hosts should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-2, because it has a rank value of 80 (30 for free ram and 50 for free cpu)
    # 2nd placement is host with id-1, because it has a rank value of 70 (10 for free ram and 60 for free cpu)
    # 3rd placement is host with id-3, because it has a rank value of 60 (50 for free ram and 10 for free cpu)
    is_deeply(
               [@rec],
               [
                  { id => "id-2", datastores => ['datastore-2'], },
                  { id => "id-1", datastores => ['datastore-1'], },
                  { id => "id-3", datastores => ['datastore-3'], }
               ],
               "should return hosts in descending order by cpu+ram "
    );
}

# validate the ranking and filtering for the given scenario, where some requirements (network labels) are not fulfilled (some hosts should be filtered)
{
    my $vm_res = new LML::VMresources( {
          ram      => 1000,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 2'],
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'                # the config defines no group_pattern, so this will be not a filter criteria
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 2, "One hosts should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-2, because it has a rank value of 80 (30 for free ram and 50 for free cpu)
    # 2nd placement is host with id-3, because it has a rank value of 60 (50 for free ram and 10 for free cpu)
    is_deeply( [@rec],
               [ { id => "id-2", datastores => ['datastore-2'], }, { id => "id-3", datastores => ['datastore-3'], } ],
               "should return hosts in descending order by cpu+ram " );
}

# validate the ranking and filtering for the given scenario, where some requirements (network labels) are not fulfilled (some hosts should be filtered)
{
    my $vm_res = new LML::VMresources( {
           ram      => 1000,
           cpu      => 2000,                                        # this is currently no filter criteria
           networks => [ 'NETWORK LABEL 1', 'NETWORK LABEL 2' ],    # all hosts support 'NETWORK LABEL 1'
           disks    => [ { size => 16000 } ],                       # disk size is currently no filter criteria
           name => 'foobar00'    # the config defines no group_pattern, so this will be not a filter criteria
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 2, "One hosts should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-2, because it has a rank value of 80 (30 for free ram and 50 for free cpu)
    # 2nd placement is host with id-3, because it has a rank value of 60 (50 for free ram and 10 for free cpu)
    is_deeply( [@rec],
               [ { id => "id-2", datastores => ['datastore-2'], }, { id => "id-3", datastores => ['datastore-3'], } ],
               "should return hosts in descending order by cpu+ram " );
}

# validate the ranking and filtering for the given scenario, where some requirements (network labels) are not fulfilled (some hosts should be filtered)
{
    my $vm_res = new LML::VMresources( {
          ram      => 1000,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 3'],      # all hosts support 'NETWORK LABEL 1'
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'                # the config defines no group_pattern, so this will be not a filter criteria
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 1, "Two hosts should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-3, because it is the only host left after filtering
    is_deeply( [@rec], [ { id => "id-3", datastores => ['datastore-3'], } ], "should return hosts in descending order by cpu+ram " );
}

# validate the ranking and filtering for the given scenario, where some requirements (ram) are not fulfilled (some hosts should be filtered)
{
    my $vm_res = new LML::VMresources( {
          ram      => 2048,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 1'],      # all hosts support this network
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'                # the config defines no group_pattern, so this will be not a filter criteria
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 2, "One host should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-2, because it has a rank value of 80 (30 for free ram and 50 for free cpu)
    # 2nd placement is host with id-3, because it has a rank value of 60 (50 for free ram and 10 for free cpu)
    # the host with id-1 got filtered because of lower bound of 2048
    is_deeply( [@rec],
               [ { id => "id-2", datastores => ['datastore-2'], }, { id => "id-3", datastores => ['datastore-3'], } ],
               "should return hosts in descending order by cpu+ram " );
}

# validate the ranking and filtering for the given scenario, where some requirements (group reliability) are not fulfilled (some hosts should be filtered)
{

    my $other_config = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );
    $other_config->{hostrules}{group_pattern} = '([a-z]{3}).*';
    my $vm_placement = new_ok( "LML::VMplacement" => [ $other_config, $simple_lab_with_three_hosts ], "grouping" ); # test builtin filter initialization

    my $vm_res = new LML::VMresources( {
          ram      => 1000,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 1'],      # all hosts support this network
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 2, "One host should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-2, because it has a rank value of 80 (30 for free ram and 50 for free cpu)
    # 2nd placement is host with id-3, because it has a rank value of 60 (50 for free ram and 10 for free cpu)
    # id-1 was filtered because id-1 already owns a foo group vm
    is_deeply( [@rec],
               [ { id => "id-2", datastores => ['datastore-2'], }, { id => "id-3", datastores => ['datastore-3'], } ],
               "should return hosts in descending order by cpu+ram with 1 host filtered by vm grouping" );
}

# validate the ranking and filtering for the given scenario,
# where we make sure that hosts removed by previous filters are not considered for group reliablity,
# see https://github.com/ImmobilienScout24/lab-manager-light/issues/31 for detailed description (issue #31)
{

    my $other_config = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );
    my $modified_lab = clone($simple_lab_with_three_hosts);
    $modified_lab->{ESXHOSTS}->{"id-3"}->{status}->{overallStatus} = "red"; # set one host to red
    $modified_lab->{ESXHOSTS}->{"id-2"}->{status}->{overallStatus} = "red"; # set one host to red
    $other_config->{hostrules}{group_pattern} = '([a-z]{3}).*';
    my $vm_placement = new_ok( "LML::VMplacement" => [ $other_config, $modified_lab ], "grouping" ); # test builtin filter initialization

    my $vm_res = new LML::VMresources( {
          ram      => 1000,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 1'],      # all hosts support this network
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 1, "Two hosts should be filtered out" );
    # in the current lab config we expect the following order:
    # Only placement is host with id-1, because its overall Status is OK
    # id-2 was filtered out because overallStatus is red
    # id-3 was filtered out because overallStatus is red
    is_deeply( [@rec],
               [ { id => "id-1", datastores => ['datastore-1'], } ],
               "should return only host id-1" );
}

# validate the ranking and filtering for the given scenario, where some requirements (group reliability) are not fulfilled (some hosts should be filtered)
{

    my $other_config = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );
    $other_config->{hostrules}{vm_host_assignment} = ['foo'];
    $other_config->{hostrules}{'foo.vm_pattern'}   = ['foobar[\d]{2}'];
    $other_config->{hostrules}{'foo.host_pattern'} = ['host_id-[1-2]'];    # host with name "host_id-3" will be filtered
    my $vm_placement = new_ok( "LML::VMplacement" => [ $other_config, $simple_lab_with_three_hosts ], "host_assignment" ); # test builtin filter initialization

    my $vm_res = new LML::VMresources( {
          ram      => 1000,
          cpu      => 2000,                     # this is currently no filter criteria
          networks => ['NETWORK LABEL 1'],      # all hosts support this network
          disks    => [ { size => 16000 } ],    # disk size is currently no filter criteria
          name     => 'foobar00'
    } );
    my @rec = $vm_placement->get_recommendations($vm_res);
    is( scalar(@rec), 2, "One host should be filtered" );
    # in the current lab config we expect the following order:
    # 1st placement is host with id-2, because it has a rank value of 80 (30 for free ram and 50 for free cpu)
    # 2nd placement is host with id-3, because it has a rank value of 70 (10 for free ram and 60 for free cpu)
    # id-3 was filtered because the name of id-3 does not match the foo.host_pattern
    is_deeply( [@rec],
               [ { id => "id-2", datastores => ['datastore-2'], }, { id => "id-1", datastores => ['datastore-1'], } ],
               "should return hosts in descending order by cpu+ram with 1 host filtered by host assignment" );
}

done_testing();
