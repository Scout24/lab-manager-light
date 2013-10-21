package LML::VMplacement::Filters::ByMemory;

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
    if (! (defined( $host->{hardware}->{memorySize} ) && defined( $host->{stats}->{overallMemoryUsage} ) )) {
        croak( "missing data in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    $error_ref = [] unless (defined $error_ref and ref($error_ref) eq "ARRAY");
    if ($vm_res->{ram} < ( $host->{hardware}->{memorySize} - $host->{stats}->{overallMemoryUsage})) {
        return 1;
    }
    push @$error_ref, "Host $host->{name} does not have $vm_res->{ram} MB free memory";
    return 0;
}

sub filter_hosts {
    my ($self, $error_ref, $vm_res, @hosts) = @_;
    return grep { $self->host_can_vm($_,$vm_res,$error_ref) } @hosts; 
}

sub get_name {
    return 'ByMemory';
}
1;
