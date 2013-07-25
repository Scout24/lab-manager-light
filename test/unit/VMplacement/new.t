use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::Lab;

BEGIN {
    use_ok "LML::VMplacement";
}

sub testfilter::host_can_vm {
    my ( $self, $host, $vm ) = @_;
    return 1;
}
my $testfilter = bless( {}, "testfilter" );

sub testranker::get_rank_value {
    my ( $self, $host ) = @_;
    return 1;
}
my $testranker = bless( {}, "testranker" );

throws_ok { new LML::VMplacement() } qr(must be an instance of LML::Lab), "dies on value for lab is not defined";
throws_ok { new LML::VMplacement( bless { foo => 1 }, "FOO" ) } qr(must be an instance of LML::Lab), "dies on value for lab is not defined";

throws_ok { new LML::VMplacement( new LML::Lab( {} ), { foo => 1 } ) } qr(2nd argument must be an Array), "dies on value for filters is not defined";
throws_ok { new LML::VMplacement( new LML::Lab( {} ), undef, { foo => 1 } ) } qr(3rd argument must be an Array), "dies on value for rankers is not defined";

throws_ok { new LML::VMplacement( new LML::Lab( {} ), [ $testfilter, "foo" ] ) } qr(filter foo has no host_can_vm method), "dies on invalid filter";
throws_ok { new LML::VMplacement( new LML::Lab( {} ), undef, [$testranker,"foo"] ) } qr(ranker foo has no get_rank_value method), "dies on invalid ranker";
throws_ok { new LML::VMplacement( new LML::Lab( {} ), undef, [$testfilter] ) } qr(ranker testfilter has no get_rank_value method), "dies on invalid ranker";
{

    new_ok( "LML::VMplacement" => [ new LML::Lab( {} ) ] );
    new_ok( "LML::VMplacement" => [ new LML::Lab( {} ), [$testfilter] ] );
    new_ok( "LML::VMplacement" => [ new LML::Lab( {} ), [$testfilter], [$testranker] ] );
    new_ok( "LML::VMplacement" => [ new LML::Lab( {} ), undef, [$testranker] ] );

    my $vm_placement = new_ok( "LML::VMplacement" => [ new LML::Lab( { foo => "bar" } ), [$testfilter], [$testranker] ] );
    is_deeply(
        $vm_placement,
        {
           lab => {
                    foo             => "bar",
                    "vms_to_update" => [],      # LML::Lab::new always sets this
           },
           filters => [$testfilter],
           rankers => [$testranker]
        },
        "ensure fake data shows up in object"
    );

}

done_testing();
