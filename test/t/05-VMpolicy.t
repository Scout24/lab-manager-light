use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Common;
use LML::Config;
use LML::Result;


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
use_ok "LML::Lab";
$isDebug = 1;

use_ok "LML::VMpolicy";

my $Pgood = new LML::VMpolicy( $C, new LML::VM("4213038e-9203-3a2b-ce9d-c6dac1f2dbbf") );
my $Pbad  = new LML::VMpolicy( $C, new LML::VM("4213c435-a176-a533-e07e-38644cf43390") );

#### validate_vm_name
#
#
is( $Pgood->validate_vm_name, undef, "should return undef for correct VM name" );
is( $Pbad->validate_vm_name, "VM name may only contain a-z0-9_- characters", "should return error message for invalid VM name" );

#### validate_hostrules_pattern
#
#
is( $Pgood->validate_hostrules_pattern, undef, "should return undef for matching VM name" );
is( $Pbad->validate_hostrules_pattern, "VM name does not match '^[a-z]{6}[0-9]{3}\$' pattern", "should return error message for non-matching VM name" );

#### validate_dns_zones
#
#
is_deeply( [$Pgood->validate_dns_zones], [], "should return undef as test VM is not present in any zone" );
is_deeply( [ new LML::VMpolicy( new LML::Config( { "hostrules" => { "dnscheckzones" => [ "google.com", "google.de" ] } } ), new LML::VM( { "NAME" => "www" } ) )->validate_dns_zones ], [ "Name conflict with 'www.google.com.'", "Name conflict with 'www.google.de.'" ], "should return two error messages as we test www.google.de and www.google.com" );

#### validate_contact_user
#
#
is_deeply( [ $Pgood->validate_contact_user ], ["Contact User ID 'User2' does not exist"], "should return error about non-existant user" );
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "contactuserid_field"  => "ci_field",
                                                                   "contactuserid_minuid" => "0",
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "ci_field" => "root" } } )
                )->validate_contact_user
           ],
           [],
           "should not return any error as root user always exists"
);
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "contactuserid_field"  => "ci_field",
                                                                   "contactuserid_minuid" => "9999",
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "ci_field" => "root" } } )
                )->validate_contact_user
           ],
           ["ci_field 'root' is not allowed"],
           "should return error that user root is not allowed"
);

######## validate_expiry
#
#
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "01.01.9999" } } )
                )->validate_expiry
           ],
           [],
           "should not return any error as 9999 is far far in the future"
);
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "01.02.1000" } } )
                )->validate_expiry
           ],
           ['VM expired on 1000-02-01T00:00:00'],
           "should return error as 1000 is far in the past"
);
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => {} } )
                )->validate_expiry
           ],
           ['Must set Expires to valid date or date/time'],
           "should return error as expires field is not set"
);
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "" } } )
                )->validate_expiry
           ],
           ["Cannot parse Expires date ''"],
           "should return error as expires field is empty"
);
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "junk date" } } )
                )->validate_expiry
           ],
           ["Cannot parse Expires date 'junk date'"],
           "should return error as expires field is empty"
);
is_deeply(
           [
              new LML::VMpolicy(
                                 new LML::Config(
                                                  {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 0
                                                    }
                                                  }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "10-11-12" } } )
                )->validate_expiry
           ],
           ["VM expired on 2012-10-11T00:00:00"],
           "should return error as 2012 is in the past (US Date format)"
);

######## validate_vm_dns_name
#
#
#
is_deeply(
    [
       new LML::VMpolicy(
                          new LML::Config(
                                           {
                                             "dhcp"      => { "appenddomain" => "junk.world", },
                                           }
                          ),
                          new LML::VM( { "NAME" => "www", "UUID" => "01234" } )
         )->validate_vm_dns_name( new LML::Lab({ "HOSTS" => { "01234" => {"HOSTNAME" => "www"} } }) )
    ],
    [],
    "should not return error as new VM name equals old VM name"
);
is_deeply(
    [
       new LML::VMpolicy(
                          new LML::Config(
                                           {
                                             "dhcp"      => { "appenddomain" => "junk.world", },
                                           }
                          ),
                          new LML::VM( { "NAME" => "www", "UUID" => "01234" } )
         )->validate_vm_dns_name( new LML::Lab({ "HOSTS" => {  } }) )
    ],
    [],
    "should not return error as VM is new and has no conflict with managed domain"
);
is_deeply(
    [
       new LML::VMpolicy(
                          new LML::Config(
                                           {
                                             "dhcp"      => { "appenddomain" => "google.com", },
                                           }
                          ),
                          new LML::VM( { "NAME" => "www", "UUID" => "01234" } )
         )->validate_vm_dns_name( new LML::Lab({ "HOSTS" => {  } }) )
    ],
    ["New VM name exists already in 'google.com'"],
    "should return error as new VM name conflicts with managed domain"
);
is_deeply(
    [
       new LML::VMpolicy(
                          new LML::Config(
                                           {
                                             "dhcp"      => { "appenddomain" => "google.com", },
                                           }
                          ),
                          new LML::VM( { "NAME" => "www", "UUID" => "01234" } )
         )->validate_vm_dns_name( new LML::Lab({ "HOSTS" => { "01234" => {"HOSTNAME" => "zzz"} } }) )
    ],
    ["Renamed VM 'www.google.com.' name exists already in 'google.com'"],
    "should return error as renamed VM name exists in managed domain"
);
is_deeply(
    [
       new LML::VMpolicy(
                          new LML::Config(
                                           {
                                             "dhcp"      => { "appenddomain" => "google.com", },
                                           }
                          ),
                          new LML::VM( { "NAME" => "frobinicate_foo_bar_baz", "UUID" => "01234" } )
         )->validate_vm_dns_name( new LML::Lab({ "HOSTS" => { "01234" => {"HOSTNAME" => "www"} } }) )
    ],
    [],
    "should return no error as renamed VM name has no conflict with managed domain"
);

######### handle_forceboot
#
#

# Prepare the test
my $VM = new LML::VM( "4213038e-9203-3a2b-ce9d-123456789abc" );
my $result = new LML::Result( $C );
my $Policy = new LML::VMpolicy( $C, $VM );
$Policy->handle_forceboot( $result );

# test the values in result, which were set via handle_forceboot from VMpolicy.pm
is($result->{redirect_target}, "menu/server.sl6.txt", "should redirect to menu/server.sl6.txt");
is($result->{statusinfo}, "force boot from LML config", "should be 'force boot from LML config'");

# test if error handling is working
$VM->{"CUSTOMFIELDS"}->{"Force Boot Target"} = "foobar";
$Policy->handle_forceboot( $result );
is_deeply(
    $result->get_errors,
    "Invalid force boot target in 'Force Boot Target'",
    "Should fail with 'Invalid force boot target in 'Force Boot Target''"
);

done_testing();
