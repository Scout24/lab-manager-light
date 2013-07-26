package LML::VMplacement::Rankers::ByOverallStatus;

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
    if ( !defined( $host->{status}->{overallStatus} ) ) {
        croak( "unknown overallStatus in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "given in " . ( caller 0 )[3] );
    }
    if ( $host->{status}->{overallStatus} eq "green" ) {
        return 100;
    }
    elsif ( $host->{status}->{overallStatus} eq "yellow" ) {
        return 0;
    }
    else {
        croak( "unknown overallStatus in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "given in " . ( caller 0 )[3] );
    }
}

1;
