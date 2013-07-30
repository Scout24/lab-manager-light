package LML::VMplacement::Rankers::ByMemory;

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

sub get_rank_value {
    my ( $self, $host ) = @_;
    if (! (defined( $host->{hardware}->{memorySize} ) && defined( $host->{stats}->{overallMemoryUsage} ) )) {
        croak( "missing data in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    return 100-int($host->{stats}->{overallMemoryUsage}/$host->{hardware}->{memorySize}*100);
}


sub get_name {
    my ( $self) = @_;
    return 'ByMemoryUsage';
}


1;
