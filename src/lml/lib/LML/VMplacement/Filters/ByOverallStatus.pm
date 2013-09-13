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
    my ( $self, $host, $vm_res, $error_ref ) = @_;
    if ( !defined( $host->{status}->{overallStatus} ) ) {
        croak( "unknown status in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] );
    }
    $error_ref = [] unless ( defined $error_ref and ref($error_ref) eq "ARRAY" );
    if (    $host->{status}->{overallStatus} eq "green"
         || $host->{status}->{overallStatus} eq "yellow" )
    {
        return 1;
    }
    push @$error_ref, "Host $host->{name} status is not 'green' or 'yellow'";
    return 0;
}

sub get_name {
    return 'ByOverallStatus';
}

1;
