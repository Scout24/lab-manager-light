package LML::VMplacement::Filters::ByNetworkLabel;

use strict;
use warnings;
use Carp;

sub new {
    my ( $class, $conf ) = @_;
    
    
    my $self = {
                 conf => $conf,
    };

    bless( $self, $class );
    return $self;
}


1;