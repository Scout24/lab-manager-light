use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::VMresources;
use LML::Lab;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByAssignableHost";
}

##################################
# test setup
###################################

my $C = new LML::Config(
    {    #
       hostrules => {    #
           'vm_host_assignment' => [ 'foo', 'bar' ],    #
           'foo.vm_pattern'   => 'foo.*',               #
           'foo.host_pattern' => 'host_for_foos.*',     #
           'bar.vm_pattern'   => 'bar.*',               #
           'bar.host_pattern' => 'host_for_bars.*'      #
       },
    }
);

my $test_host_1 = {
    id       => "id-1",
    networks => [ "network-1", "network-2" ],
    # other attributes are unimportant
};

my $vm_res;

##################################
# test cases
###################################

throws_ok { new LML::VMplacement::Filters::ByAssignableHost( {} ) } qr(must be an instance of LML::Config), "dies on value for config is not defined";

# happy path tests for instantiation with new()
{
    my $filter = new_ok( "LML::VMplacement::Filters::ByAssignableHost" => [$C] );
    is( $filter->{config}, $C, "Config must be stored as instance member" );

    is_deeply(
               $filter->{vm_host_assignments},
               {
                  foo => { vm_pattern => 'foo.*', host_pattern => 'host_for_foos.*' },
                  bar => { vm_pattern => 'bar.*', host_pattern => 'host_for_bars.*' }
               },
               "should store parsed vm to host assignments properly "
    );
}

# bar.vm_pattern is missing and should be croaked
{
    my $missconfigured_config = new LML::Config(
        {    #
           hostrules => {    #
               'vm_host_assignment' => [ 'foo', 'bar' ],    #
               'foo.vm_pattern'   => 'foo.*',               #
               'foo.host_pattern' => 'host_for_foos.*',     #
               'bar.host_pattern' => 'host_for_bars.*'      #
           },
        }
    );
    throws_ok { new LML::VMplacement::Filters::ByAssignableHost($missconfigured_config) } qr(config is not properly set for bar.vm_pattern), "dies if config is not set properly";
}

# bar.host_pattern is missing and should be croaked
{
    my $missconfigured_config = new LML::Config(
        {                                                   #
           hostrules => {                                   #
               'vm_host_assignment' => [ 'foo', 'bar' ],    #
               'foo.vm_pattern'   => 'foo.*',               #
               'foo.host_pattern' => 'host_for_foos.*',     #
               'bar.vm_pattern'   => 'bar.*',               #
           },
        }
    );
    throws_ok { new LML::VMplacement::Filters::ByAssignableHost($missconfigured_config) } qr(config is not properly set for bar.host_pattern), "dies if config is not set properly";
}

# host_can_vm: should not filter a host when the corresponding host_pattern matches the host name
{
    my $filter = new_ok( "LML::VMplacement::Filters::ByAssignableHost" => [$C] );
    
    my $vm_res = new LML::VMresources( { name => 'foobar00' } );
    my $host = {name => "host_for_foos.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 1, 'the host should not be filtered, because the corresponding host_pattern matches the host name');

    $vm_res = new LML::VMresources( { name => 'barfoo00' } );
    $host = {name => "host_for_bars.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 1, 'the host should not be filtered, because the corresponding host_pattern matches the host name');
}


# host_can_vm: should not filter a host when the no vm_pattern matches for the vm name
{
    my $filter = new_ok( "LML::VMplacement::Filters::ByAssignableHost" => [$C] );
    
    my $vm_res = new LML::VMresources( { name => 'veryDifferent01' } );
    my $host = {name => "host_for_foos.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 1, 'the host should not be filtered, because the corresponding host_pattern matches the host name');
}

# host_can_vm: should not filter a host when config defines empty vm_host_assignments
{
    my $config_with_empty_vm_host_assignment = new LML::Config(
    {    #
       hostrules => {    #
           'vm_host_assignment' => [  ],    #
       },
    });

    my $filter = new_ok( "LML::VMplacement::Filters::ByAssignableHost" => [$config_with_empty_vm_host_assignment] );
    
    my $vm_res = new LML::VMresources( { name => 'veryDifferent01' } );
    my $host = {name => "host_for_foos.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 1, 'the host should not be filtered, because the corresponding host_pattern matches the host name');
}

# host_can_vm: should not filter a host when config defines no vm_host_assignments
{
    my $config_with_no_vm_host_assignment = new LML::Config(
    {    #
       hostrules => {        },
    });

    my $filter = new_ok( "LML::VMplacement::Filters::ByAssignableHost" => [$config_with_no_vm_host_assignment] );
    
    my $vm_res = new LML::VMresources( { name => 'veryDifferent01' } );
    my $host = {name => "host_for_foos.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 1, 'the host should not be filtered, because the corresponding host_pattern matches the host name');
}

# host_can_vm: should filter a host when the corresponding host_pattern NOT matches the host name
{
    my $filter = new_ok( "LML::VMplacement::Filters::ByAssignableHost" => [$C] );
    
    my $vm_res = new LML::VMresources( { name => 'foobar00' } );
    my $host = {name => "host_for_bars.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 0, 'the host should be filtered, because the corresponding host_pattern not matches the host name');

    $vm_res = new LML::VMresources( { name => 'barfoo00' } );
    $host = {name => "host_for_foos.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 0, 'the host should be filtered, because the corresponding host_pattern not matches the host name');
    
    $vm_res = new LML::VMresources( { name => 'foobar00' } );
    $host = {name => "peng_host_for_foos.some.domain",};
    is($filter->host_can_vm($host, $vm_res), 0, 'the host should be filtered, because the corresponding host_pattern not matches the host name');
    
}





done_testing();
