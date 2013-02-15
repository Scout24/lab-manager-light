package LML::Config;

use strict;
use warnings;

use LML::Common;

sub new {
    my ($class,@configfiles) = @_;
    my %C = LoadConfig(@configfiles);
    my $self  = \%C;
    bless( $self, $class );
    return $self;
}

sub get {
    my ($self,$section,$key) = @_;
    if ( exists( $self->{$section}->{$key} ) ) {
        return $self->{$section}->{$key};
    } else {
        return undef;
    }
}

1;