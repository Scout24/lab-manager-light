use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok "LML::Common";
}

# test basic config subsystem
LoadConfig( "src/lml/default.conf", "test/data/test.conf" );
isa_ok( \%CONFIG, "HASH", "CONFIG hash" );
is( $CONFIG{ "lml"}{"datadir"}, "test/temp", "test datadir set to test/temp" );
ok ($LML_VERSION,"we have a version");
isa_ok (\$isDebug, "SCALAR", "isDebug variable");


done_testing;
