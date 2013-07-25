use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;

BEGIN {
    use_ok "LML::VMresources";
}

#verify ram key
dies_ok { new LML::VMresources( { ram => "some string" } ) } "dies on value for ram is not a number";
dies_ok { new LML::VMresources( { ram => 0 } ) } "dies on value for ram is smaller than 1";
dies_ok { new LML::VMresources( { ram => -1 } ) } "dies on value for ram is smaller than 1";
dies_ok { new LML::VMresources( { ram => 1.5 } ) } "dies on value for ram is not a natural number";

#verify cpu key
dies_ok { new LML::VMresources( { cpu => "some string" } ) } "dies on value for cpu is not a number";
dies_ok { new LML::VMresources( { cpu => 0 } ) } "dies on value for cpu is smaller than 1";
dies_ok { new LML::VMresources( { cpu => -1 } ) } "dies on value for cpu is smaller than 1";
dies_ok { new LML::VMresources( { cpu => 1.5 } ) } "dies on value for cpu is not a natural number";

#verify disks key
dies_ok { new LML::VMresources( { disks => "not a list" } ) } "dies on value for disks is not a list";
dies_ok { new LML::VMresources( { disks => [ {}, "not a hash" ] } ) } "dies on at least one entry in disks list is not a hash";
dies_ok { new LML::VMresources( { disks => [ { size => 16000 }, {} ] } ) } "dies on at least one entry in disks list is a hash but contains no size key";
dies_ok { new LML::VMresources( { disks => [ { size => 16000 }, { size => "not a number" } ] } ) } "dies on at least one entry in disks list is a hash but contains a size key with non numeric value";
dies_ok { new LML::VMresources( { disks => [ { size => 16000 }, { size => 0 } ] } ) } "dies on at least one entry in disks list is a hash but contains a size key with numeric value not greater 0";

#verify networks key
dies_ok { new LML::VMresources( { networks => "not a list" } ) } "dies on value for networks is not a list";

# verify defaults
{
    my $obj = new_ok( "LML::VMresources" => [] );
    #diag( "Default Object:\n", explain($obj) );
}

# verfiy happy trail for valid paramerters
{
    new_ok( "LML::VMresources" => [ { ram   => 1 } ] );
    new_ok( "LML::VMresources" => [ { cpu   => 1 } ] );
    new_ok( "LML::VMresources" => [ { disks => [ { size => 16000 }, { size => 16000 } ] } ] );
    new_ok( "LML::VMresources" => [ { disks => [] } ] );
    new_ok( "LML::VMresources" => [ { networks => [ "network1", "network2" ] } ] );
    new_ok( "LML::VMresources" => [ { networks => [] } ] );

    my $vm_resource = new_ok( "LML::VMresources" => [ { ram => 1, cpu => 1, disks => [ { size => 16000 }, { size => 24000 } ], networks => [ "network1", "network2" ] } ] );
    is_deeply( $vm_resource, { ram => 1, cpu => 1, disks => [ { size => 16000 }, { size => 24000 } ], networks => [ "network1", "network2" ] }, "given arguments must be stored in data" );

}

done_testing();
