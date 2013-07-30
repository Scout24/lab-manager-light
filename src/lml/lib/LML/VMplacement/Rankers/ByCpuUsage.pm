package LML::VMplacement::Rankers::ByCpuUsage;

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
    if ( ! (defined( $host->{stats}->{overallCpuUsage} ) &&  defined( $host->{hardware}->{totalCpuMhz}))) {
        croak( "missing data in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "given in " . ( caller 0 )[3] );
    }
    return 100-int($host->{stats}->{overallCpuUsage}/$host->{hardware}->{totalCpuMhz}*100);
}

sub get_name {
    my ( $self) = @_;
    return 'ByCpuUsage';
}


1;
