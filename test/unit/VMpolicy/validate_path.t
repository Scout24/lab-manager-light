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

######## check_ignore_path
#
#
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "allow_paths"    => ["DC/vm/.*"],
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/users" } )
                )->validate_path
           ],
           [],
           "should not return errors"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "allow_paths"    => ["DC/vm/private"],
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/users" } )
                )->validate_path
           ],
           ["VM not allowed in 'DC/vm/users' folder"],
           "should return error as VM path is not allowed"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "allow_paths"    => ["DC/vm/.*"],
                                                                   "deny_paths"     => ["DC/vm/private"],
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/users" } )
                )->validate_path
           ],
           [],
           "should not return errors"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "allow_paths"    => ["DC/vm/.*"],
                                                                   "deny_paths"     => ["DC/vm/us.*"],
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/users" } )
                )->validate_path
           ],
           ["VM not allowed in 'DC/vm/users' folder"],
           "should return errors"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/private" } )
                )->validate_path
           ],
           [],
           "should not return errors as no paths are set"
);

done_testing();