use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::TokenReplacer";
}

dies_ok { new LML::TokenReplacer() } "dies on no args";
dies_ok { new LML::TokenReplacer("foo") } "dies on string arg";
dies_ok { new LML::TokenReplacer( [ 1, 2, 3 ] ) } "dies on list arg";

my $obj = new_ok( "LML::TokenReplacer" => [ { foor => 1 } ] );
is_deeply( $obj->{dictionary}, { foor => 1 }, "dictionary equals input" );

$obj = new_ok( "LML::TokenReplacer" => [ { foor => 1 }, { FOOR => 2, bar => { baz => 3, GAa => { goof => 5 } } } ] );
is_deeply( $obj->{dictionary}, { foor => 2, "bar/baz" => 3, "bar/gaa/goof" => 5,}, "dictionary equals input" );

$obj = new_ok( "LML::TokenReplacer" => [ { foor => 1 }, bless({ FOOR => 2, bar => { baz => 3, GAa => { goof => 5 } } }, "foo") ] );
is_deeply( $obj->{dictionary}, { foor => 2, "bar/baz" => 3, "bar/gaa/goof" => 5,}, "dictionary equals input" );

done_testing();
