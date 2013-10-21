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
    my ( $self, $host, $vm_res, $error_ref ) = @_;
    if ( !defined( $host->{status}->{active} ) ) {
        croak( "unknown status in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] );
    }
    $error_ref = [] unless ( defined $error_ref and ref($error_ref) eq "ARRAY" );
    if ( $host->{status}->{active} ) {
        return 1;
    }
    push @$error_ref, "Host $host->{name} is not active";
    return 0;
}

sub filter_hosts {
    my ($self, $error_ref, $vm_res, @hosts) = @_;
    return grep { $self->host_can_vm($_,$vm_res,$error_ref) } @hosts; 
}

sub get_name {
    return ( __PACKAGE__ =~ m((\w+?)$) )[0];
}

1;
