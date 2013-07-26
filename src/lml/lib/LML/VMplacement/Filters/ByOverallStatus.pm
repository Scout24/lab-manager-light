package LML::VMplacement::Filters::ByOverallStatus;

use strict;
use warnings;
use Carp;

sub new {
    my ($class) = @_;

    my $self = {};

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host ) = @_;
    return defined( $host->{status}->{overallStatus} )
      && (    $host->{status}->{overallStatus} eq "green"
           || $host->{status}->{overallStatus} eq "yellow" ) ? 1 : 0;
}

1;
