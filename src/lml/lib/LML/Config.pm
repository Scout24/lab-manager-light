package LML::Config;

use strict;
use warnings;

use LML::Common;

sub new {
    my $class = shift;
    my $self;
    if (ref($_[0]) eq "LML::Config" ) {
        
    }
    elsif (ref($_[0]) eq "HASH" ) {
        $self = shift;
    } else {
        my %C = LoadConfig(@_);
        $self  = \%C;
    }
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

sub set {
    my ($self,$section,$key,$value) = @_;
    $self->{$section}->{$key} = $value;
    return $value;
}

sub labfile {
    my $self = shift;
    # TODO deal with the get() returning undef
    return $self->get("lml","datadir")."/lab.conf";
}

1;