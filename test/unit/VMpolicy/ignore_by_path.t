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
                                                                   "ignore_paths"    => ["DC/vm/private"],
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/users" } )
                )->ignore_vm_by_path
           ],
           [0],
           "should return false as VM path is not in ignore paths"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                                   "ignore_paths"    => ["DC/vm/private"],
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/private" } )
                )->ignore_vm_by_path
           ],
           [1],
           "should return true as VM path is in ignore paths"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "vsphere" => {
                                                    } }
                                 ),
                                 new LML::VM( { "PATH" => "DC/vm/private" } )
                )->ignore_vm_by_path
           ],
           [0],
           "should return false as no ignore path is set"
);

done_testing();