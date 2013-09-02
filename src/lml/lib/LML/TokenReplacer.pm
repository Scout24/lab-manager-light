package LML::TokenReplacer;

use strict;
use warnings;

use LML::Common;
use Carp;
use Data::Dumper;

use Scalar::Util qw(reftype);

# new object, takes list of references to things that look like hash-of-hash as replacements
sub new {
    my ( $class, @data_hashes ) = @_;
    my %dictionary = ();
    if ( scalar(@data_hashes) ) {
        my $c = 1;
        foreach my $data (@data_hashes) {
            
            if ( __is_hash_ref( $data ) ) {
                my %flattened_hash = __lower_and_flatten_hash(%$data); 
                @dictionary{keys %flattened_hash} = values %flattened_hash;
            }
            else {
                croak 'Argument Nr. $c could not be parsed as hashref at ' . ( caller(0) )[3] . '.\n';
            }
        }
    }
    else {
        croak 'Must provide at least one hashref at ' . ( caller(0) )[3] . '.\n';
    }
    my $self = { dictionary => \%dictionary };
    bless( $self, $class );
    return $self;
}

sub replace {
    my ($self,$data) = @_;
    $data =~ s(
                 %%%[\w/]+%%%
             )(
                 $self->_get_token_replacement($&)
             )xeig;
    return $data;                       
}


sub _get_token_replacement {
    my ( $self, $match) = @_;    # match is %%%token%%%, $tokens is hashref to tokens
    my $token = lc( substr( $match, 3, -3 ) );
    return defined $self->{dictionary}->{$token} ? $self->{dictionary}->{$token} : "!!!NO_TOKEN_$token!!!";
}

sub __is_hash_ref {
    my $type = reftype( $_[0] );
    return defined($type) && $type eq "HASH";
}

sub __lower_and_flatten_hash {
    my (%hash ) = @_;
    my %result = ();
    while ( my ( $key, $value ) = each %hash ) {
        if ( __is_hash_ref( $value )) {
            my %subhash = __lower_and_flatten_hash(%$value);
            @result{map { $_= lc "$key/$_" } keys %subhash} = values %subhash;
        }
        else {
            $result{lc $key} = $value;
        }
    }
    return %result;

}

1;
