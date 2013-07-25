package LML::VMplacement;

use strict;
use warnings;
use Carp;

sub new {
    my ( $class, $lab, $filters, $rankers) = @_;

    croak( "1st argument must be an instance of LML::Lab called at " . ( caller 0 )[3] ) unless ( ref($lab) eq "LML::Lab" );
    
    if (defined($filters)){
        croak( "2nd argument must be an Array Ref called at " . ( caller 0 )[3] ) unless ( ref($filters) eq "ARRAY" );
        foreach (@$filters) {
            croak( "filter ".(ref($_) ? ref($_) : $_)." has no host_can_vm method called at " . ( caller 0 )[3] ) unless ( $_->can("host_can_vm"));
        }
    } else {
        # todo set default filters
        $filters = [];
    }

    if (defined($rankers)){
        croak( "3rd argument must be an Array Ref called at " . ( caller 0 )[3] ) unless ( ref($rankers) eq "ARRAY" );
        foreach (@$rankers) {
            croak( "ranker ".(ref($_) ? ref($_) : $_)." has no get_rank_value method called at " . ( caller 0 )[3] ) unless ( $_->can("get_rank_value"));
        }
    } else {
        # todo set default rankers
        $rankers = [];
    }

    my $self = {
        lab => $lab,
        filters => $filters,
        rankers => $rankers,
    };

    
    bless( $self, $class );
    return $self;
}

1;
