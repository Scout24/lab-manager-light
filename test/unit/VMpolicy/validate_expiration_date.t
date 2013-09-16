use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Common;
use LML::Config;
use LML::Result;
use LML::VM;
use LML::VMpolicy;

use DateTime;

######## validate_expiry
#
#
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1,
                                                                   "expires_maximum"  => 10
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => DateTime->now()->add(days=>1)->date() } } )
                )->validate_expiry
           ],
           [],
           "should not return any error as 9999 is far far in the future"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1,
                                                                   "expires_maximum"  => 10
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "01.02.1000" } } )
                )->validate_expiry
           ],
           ['VM expired on 1000-02-01T00:00:00'],
           "should return error as 1000 is far in the past"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1,
                                                                   "expires_maximum"  => 10
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => {} } )
                )->validate_expiry
           ],
           ['Must set Expires to valid date or date/time'],
           "should return error as expires field is not set"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1,
                                                                   "expires_maximum"  => 10
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "" } } )
                )->validate_expiry
           ],
           ["Cannot parse Expires date ''"],
           "should return error as expires field is empty"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1,
                                                                   "expires_maximum"  => 10
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "junk date" } } )
                )->validate_expiry
           ],
           ["Cannot parse Expires date 'junk date'"],
           "should return error as expires field is empty"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 0,
                                                                   "expires_maximum"  => 10
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "10-11-12" } } )
                )->validate_expiry
           ],
           ["VM expired on 2012-10-11T00:00:00"],
           "should return error as 2012 is in the past (US Date format)"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "expires_field"    => "Expires",
                                                                   "expires_european" => 1,
                                                                   "expires_maximum"  => 10,
                                                    } }
                                 ),
                                 new LML::VM( { "CUSTOMFIELDS" => { "Expires" => "01.01.9999" } } )
                )->validate_expiry
           ],
           ["VM is not allowed to expire more than 10 days in the future"],
           "should return error as VM expires more than 10 days in the future"
);



done_testing();
