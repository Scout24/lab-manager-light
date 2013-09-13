use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::VMresources;
use LML::Lab;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByGroupReliability";
}

##################################
# test setup
###################################

my $C = new LML::Config( { hostrules => { group_pattern => '([a-z]{3}).*' }, } );    # first three letters in vm_name

my $test_host_1 = {
    id   => "id-1",
    name => "esx01.domain",
    vms  => [ "vm-1-of-group-foo", "vm-1-of-group-bar", "vm-1-of-group-gii", "vm-2-of-group-gii" ]
      # other attributes are unimportant
};

my $test_host_2 = {
    id   => "id-2",
    name => "esx02.domain",
    vms  => [ "vm-2-of-group-bar", "vm-3-of-group-gii" ]
      # other attributes are unimportant
};

# Our Lab contains the following scenario:
#   We have two esx hosts and three groups of vms (foo, bar, gii).
#   Esx host 1 owns one foo vm, one bar vm and two gii vms.
#   Esx host 2 owns no foo vm,  one bar vm and one gii vm.
#
# In our test cases we can test, that our filter will filter esx host 1 when a foo or a gii vm will be created,
# because for this vm group esx hosts 2 owns lesser vm of the same group type.
#
# When another bar vm will be created no esx host will be filtered, because they own the same number of bar vms.
#
my $lab = new LML::Lab( {
       "ESXHOSTS" => {
                       $test_host_1->{id} => $test_host_1,
                       $test_host_2->{id} => $test_host_2,
       },
       "HOSTS" => {
           "1234545-2344-222-2344-9898239874" => {
                                                   "NAME"  => "foobar23",             # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-1-of-group-foo"
           },
           "9098873-9098-111-908934-93455574" => {
                                                   "NAME"  => "barfoo23",             # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-1-of-group-bar"
           },
           "9098873-9098-333-908934-98982374" => {
                                                   "NAME"  => "barfoo24",             # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-2-of-group-bar"
           },
           "7222273-9098-444-908984-91111174" => {
                                                   "NAME"  => "giibas23",             # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-1-of-group-gii"
           },
           "7234473-9098-555-933333-91111174" => {
                                                   "NAME"  => "giibas24",             # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-2-of-group-gii"
           },
           "7222273-9098-666-952424-91111174" => {
                                                   "NAME"  => "giibas25",             # TODO: decide wether to use "NAME" or "HOSTNAME"
                                                   "VM_ID" => "vm-3-of-group-gii"
           },
       },
    } );

my $vm_res;

##################################
# test cases
###################################

new_ok( "LML::VMplacement::Filters::ByGroupReliability" => [ $lab, $C ] );
throws_ok { new LML::VMplacement::Filters::ByGroupReliability( {}, $C ) } qr(must be an instance of LML::Lab),
  "dies on value for lab is not defined";
throws_ok { new LML::VMplacement::Filters::ByGroupReliability( $lab, {} ) } qr(must be an instance of LML::Config),
  "dies on config is not defined";

my $filter = new LML::VMplacement::Filters::ByGroupReliability( $lab, $C );

# when a vm with name foobar90 should be created, the test_host_1 should get filtered, because instead of test_host_2 he owns a vm of same group
{
    $vm_res = new LML::VMresources( { name => 'foobar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        0, "should return false for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
}

# when a vm with name barbar90 should be created, the no hosts should get filtered, because all hosts own the same number of vm of same group
{
    $vm_res = new LML::VMresources( { name => 'barbar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
}

# when a vm with name barbar90 should be created, the no hosts should get filtered, because all hosts own the same number of vm of same group
{
    $vm_res = new LML::VMresources( { name => 'giibar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        0, "should return false for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
}

# when no group pattern was defined, the filter should pass everything
{
    my $C = new LML::Config( { hostrules => {}, } );    # no group pattern
    my $filter = new LML::VMplacement::Filters::ByGroupReliability( $lab, $C );
    $vm_res = new LML::VMresources( { name => 'foobar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
    $vm_res = new LML::VMresources( { name => 'barbar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
    $vm_res = new LML::VMresources( { name => 'giibar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
}

# when no group pattern was defined, the filter should pass everything
{
    my $C =
      new LML::Config( { hostrules => { group_pattern => '(this is a non matching group pattern)' }, } ); # group pattern with 3 letters (i)
    my $filter = new LML::VMplacement::Filters::ByGroupReliability( $lab, $C );
    $vm_res = new LML::VMresources( { name => 'foobar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
    $vm_res = new LML::VMresources( { name => 'barbar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
    $vm_res = new LML::VMresources( { name => 'giibar90' } );
    is( $filter->host_can_vm( $test_host_1, $vm_res ),
        1, "should return true for host $test_host_1->{id} when a vm with name " . $vm_res->{name} . " should be created" );
    is( $filter->host_can_vm( $test_host_2, $vm_res ),
        1, "should return true for host $test_host_2->{id} when a vm with name " . $vm_res->{name} . "  should be created" );
}

done_testing();
