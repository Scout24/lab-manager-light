package LML::VMplacement::Filters::ByActive;

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
    if (!defined( $host->{status}->{active} ) ) {
        croak( "unknown status in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    return $host->{status}->{active} ? 1 : 0;
}

sub get_name {
    return (__PACKAGE__ =~ m((\w+?)$))[0];
}

1;
