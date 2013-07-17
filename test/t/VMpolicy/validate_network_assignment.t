use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Common;
use LML::Config;
use LML::VM;
use LML::Lab;

use_ok "LML::VMpolicy";

#$isDebug = 1;

######## validate_vm_dns_name
#
#
#
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( { "network_assignment" => { "other_net" => [ "gaga.*", "dev[0-9]{3}" ] } } ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_network_assignment()
           ],
           [],
           "should not return error as no network_assignment given for used networks"
);

is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( { "network_assignment" => { "arc.int" => [ "gaga.*", "dev[0-9]{3}" ] } } ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_network_assignment()
           ],
           [],
           "should not return error as all networks are allowed"
);

is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( { "network_assignment" => { "foo" => [ "gaga.*", "pro[0-9]{3}" ] } } ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_network_assignment()
           ],
           ["VM not authorized for network 'foo'"],
           "should return error that foo is forbidden"
);

is_deeply( [
       new LML::VMpolicy(
           new LML::Config( {
                  "network_assignment" => {
                                            "arc.int" => [ "gaga.*", "pro[0-9]{3}" ],
                                            "foo"     => ["foo[0-9]{3}"] }
               }
           ),
           new LML::VM( {
                          "NAME"       => "dev123",
                          "NETWORKING" => [ {
                                              "MAC"     => "egal",
                                              "NETWORK" => "arc.int"
                                            },
                                            {
                                              "MAC"     => "egal",
                                              "NETWORK" => "foo"
                                            }
                          ],
                        } )
         )->validate_network_assignment()
    ],
    ["VM not authorized for network 'arc.int'","VM not authorized for network 'foo'"],
    "should return error that arc.int and foo are forbidden"
);
done_testing();
