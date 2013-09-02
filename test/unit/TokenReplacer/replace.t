use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::TokenReplacer";
}

my $r = new LML::TokenReplacer({ token => "true", othertoken1 => "false", foo => {bar =>5}  } );

my $tokentext = "test %%%token%%% is %%%TOKen%%% and not %%%othertoken1%%%,
but %%%otherTOKEN1%%% might still be %%%token%%%, but can't be %%%invalid_token%%%

config %%%foo/bar%%%
";

my $replaced_test = "test true is true and not false,
but false might still be true, but can't be !!!NO_TOKEN_invalid_token!!!

config 5
";
 
is ($r->replace($tokentext),$replaced_test,"valid replacement");

done_testing();