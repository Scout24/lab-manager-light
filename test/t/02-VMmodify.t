use strict;
use warnings;

use Test::More;
use Test::MockObject;
use LML::Common;

# load shipped configuration
LoadConfig( "src/lml/default.conf", "test/data/test.conf" );

# mock needed function from VMware.pm
my $mock = Test::MockObject->new();
my $off_value = undef;

$mock->fake_module('LML::VMware' => (
    'get_vm_data'       => sub {
        my $search_uuid = shift;
        my %VM = %{ ReadVmFile() };
        return %{$VM{$search_uuid}};
    },
    'setVmCustomValueU' => sub {
        my $search_uuid = shift;
        my $forceboot_field = shift;
        $off_value = shift;
    }
));

use_ok "LML::VMmodify";
remove_forceboot('42130272-a509-8010-6e85-4e01cb1b7284');

my $test_off_value = 0;
if (($off_value eq "") or ($off_value eq "OFF")) { $test_off_value = 1; }
ok($test_off_value == 1, "Test if answer from remove_forceboot function is '' or 'OFF'");

done_testing;
