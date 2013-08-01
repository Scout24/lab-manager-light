package LML::VMplacement::Filters::ByOverallStatus;

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
    my ( $self, $host ) = @_;
    if (!defined( $host->{status}->{overallStatus} ) ) {
        croak( "unknown status in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    return $host->{status}->{overallStatus} eq "green"
      || $host->{status}->{overallStatus} eq "yellow" ? 1 : 0;
}

sub get_name {
    return 'ByOverallStatus';
}

1;
