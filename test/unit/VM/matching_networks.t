use strict;
use warnings;

use Test::More;
use Test::Warn;
use LML::VM;

my $VM = new_ok(
    "LML::VM" => [ {
           "NETWORKING" => [ {
                                "MAC"     => "egal",
                                "NETWORK" => "arc.int"
                             },
                             {
                                "MAC"     => "egal",
                                "NETWORK" => "foo"
                             }
           ],
        } ] );
is_deeply( [ $VM->matching_networks() ],        [],      "no networks to match yield no return" );
is_deeply( [ $VM->matching_networks("xyz.*") ], [],      "empty array if regex not match" );
is_deeply( [ $VM->matching_networks("foo") ],   ["foo"], "direct match with exact name" );
is_deeply( [ $VM->matching_networks( "foo", "arc.int" ) ], [ "arc.int", "foo" ],
           "direct match with several exact names in attached order" );
is_deeply( [ $VM->matching_networks("arc.*") ], ["arc.int"], "match by regex" );
done_testing;
