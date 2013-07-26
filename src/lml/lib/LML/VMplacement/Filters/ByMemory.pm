package LML::VMplacement::Filters::ByMemory;

use strict;
use warnings;
use Carp;
use Data::Dumper;

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host, $vm_res ) = @_;
    if (! (defined( $host->{hardware}->{memorySize} ) && defined( $host->{stats}->{overallMemoryUsage} ) )) {
        croak( "missing data in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    return $vm_res->{ram} < ( $host->{hardware}->{memorySize} - $host->{stats}->{overallMemoryUsage}) ? 1 : 0;
}

1;
