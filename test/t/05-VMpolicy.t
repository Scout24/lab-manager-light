use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Common;
use LML::Config;

# load shipped configuration
my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

# mock needed function from LML::VMware
use LML::VMware;
my $mock            = new Test::MockModule('LML::VMware');
my $off_value       = undef;
my $extraopts_key   = undef;
my $extraopts_value = undef;

$mock->mock(
    'get_vm_data',
    sub {
        my $uuid   = shift;
        my %VM_ALL = %{ ReadVmFile() };

        #diag("Mock get_vm_data($uuid):\n");
        return () unless ( exists $VM_ALL{$uuid} );
        return %{ $VM_ALL{$uuid} };

    }
);

$mock->mock(
    'setVmCustomValueU',
    sub {
        my $uuid            = shift;
        my $forceboot_field = shift;
        $off_value = shift;

        #diag("Mock setVmCustomValueU($uuid,$forceboot_field,$off_value)\n");
        return 1;
    }
);

$mock->mock(
    'setVmExtraOptsU',
    sub {
        my $uuid;
        ( $uuid, $extraopts_key, $extraopts_value ) = @_;

        #diag("Mock setVmExtraOptsU($uuid,$extraopts_key,$extraopts_value)\n");
        return 1;
    }
);
use_ok "LML::VM";

$isDebug = 1;

use_ok "LML::VMpolicy";

my $Pgood = new LML::VMpolicy( $C, new LML::VM("4213038e-9203-3a2b-ce9d-c6dac1f2dbbf") );
my $Pbad  = new LML::VMpolicy( $C, new LML::VM("4213c435-a176-a533-e07e-38644cf43390") );

is( $Pgood->validate_vm_name, undef, "should return undef for correct VM name" );
is( $Pbad->validate_vm_name, "VM name may only contain a-z0-9_- characters", "should return error message for invalid VM name" );

is( $Pgood->validate_hostrules_pattern, undef, "should return undef for matching VM name" );
is( $Pbad->validate_hostrules_pattern, "VM name does not match '^[a-z]{6}[0-9]{3}\$' pattern", "should return error message for non-matching VM name" );

is( $Pgood->validate_dns_zones, undef, "should return undef as test VM is not present in any zone" );
is_deeply(
    [ new LML::VMpolicy( 
            new LML::Config( { 
                                "hostrules" => { 
                                                "dnscheckzones" => [ 
                                                                    "google.com", 
                                                                    "google.de" 
                                                                    ] 
                                                } 
                              } ),
            new LML::VM( { "NAME" => "www" } ) )->validate_dns_zones 
    ],
    ["Name conflict with 'www.google.com.'", "Name conflict with 'www.google.de.'" ],
    "should return two error messages as we test www.google.de and www.google.com"
);
done_testing();
