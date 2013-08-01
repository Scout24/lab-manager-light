package LML::VMplacement::Filters::ByNetworkLabel;

use strict;
use warnings;
use Carp;

sub new {
    my ($class, $lab) = @_;
    
    croak( "1st argument must be an instance of LML::Lab called at " . ( caller 0 )[3] ) unless ( ref($lab) eq "LML::Lab" );
    
    
    my $self = {
        lab => $lab
    };

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ($self, $host, $vm_res) = @_;
    my @network_labels_provided_host = $self->_get_network_labels_provided_by($host);

    foreach my $label (@{$vm_res->{networks}}){
        return 0 unless $self->_host_provides_network($label, @network_labels_provided_host) 
    }
    
    return 1;
}

sub get_name {
    return 'ByNetworks';
}

sub _host_provides_network{
    my ($self, $network_label, @provided_network_labels) = @_;
    return 1 if ( grep { /^$network_label/}  @provided_network_labels  ) ;
    return 0;
}

sub _get_network_labels_provided_by{
    my ($self, $host) = @_;
    return map {$self->{lab}->{NETWORKS}->{$_}->{name} } @{$host->{networks}};
}


1;