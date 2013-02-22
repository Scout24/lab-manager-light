use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok "LML::Common";
    use_ok "LML::Config";
}

# test if we can load config from config files
my $C = new_ok( "LML::Config" => [ "src/lml/default.conf", "test/data/test.conf" ] );
is_deeply( $C->get( 'hostrules', 'dnscheckzones' ), [ "some.zone", "some.other.zone" ], "should give the value from default.conf (some.zone, some.other.zone)" );
is( $C->get( 'lml', 'datadir' ), "test/temp", "should give the value from test.conf (test/temp)" );
is( $C->labfile, "test/temp/lab.conf", "should give lab file from test data" );
# test if old direct way also works
is( $CONFIG{'lml'}{'datadir'}, "test/temp", "should give the value from test.conf (test/temp) via direct access to CONFIG Hash" );

# test if we can load config from the constructor
is( new LML::Config( { "foo" => { "bar" => "baz" } } )->get( "foo", "bar" ), "baz", "should give value from constructor (baz)" );

done_testing();
