package LML::VMresources;

use strict;
use warnings;
use Carp;

sub new {
    my ( $class, $input ) = @_;

    my $self = {
                 ram      => 2048,
                 cpu      => 1,
                 networks => [],
                 disks    => [],
                 name => undef
    };

    if ( defined($input) ) {
        croak( "Arg must be hashref of vm resources in " . ( caller 0 )[3] ) unless ( ref($input) eq "HASH" );
        # merge hashes http://learn.perl.org/faq/perlfaq4.html#How-do-I-merge-two-hashes- with shallow overwriting
        # hashref must be dereferenced first
        @{$self}{ keys %$input } = values %$input;
    }

    sub is_natural_number {
        return ( defined( $_[0] ) and $_[0] =~ qr(^\d+$) and $_[0] > 0 ) ? 1 : 0;
    }

    croak( "RAM size \"$self->{ram}\" given in " . ( caller(0) )[3] . " must be a natural number >0" ) unless ( is_natural_number( $self->{ram} ) );

    croak( "cpu count \"$self->{cpu}\" defined in " . ( caller(0) )[3] . " must be a natural number >0" ) unless ( is_natural_number( $self->{cpu} ) );

    croak( "disks given in " . ( caller(0) )[3] . " must be an array reference" ) unless ( ref( $self->{disks} ) eq "ARRAY" );

    # Check the consistency of the disks hash
    my $count = 0;
    foreach ( @{ $self->{disks} } ) {
        croak( "disk $count size given in " . ( caller(0) )[3] . " must be a natural number >0" ) unless ( is_natural_number( $_->{size} ) );
        $count++;
    }

    # Check the consistency of the networks array
    croak( "networks given in " . ( caller(0) )[3] . " must be an array reference" ) unless ( ref( $self->{networks} ) eq "ARRAY" );

    bless( $self, $class );
    return $self;
}

1;
