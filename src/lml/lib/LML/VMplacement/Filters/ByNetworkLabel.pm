package LML::VMplacement::Filters::ByNetworkLabel;

use strict;
use warnings;
use Carp;

sub new {
    my ( $class, $lab, $config ) = @_;

    croak( "1st argument must be an instance of LML::Lab called at " .    ( caller 0 )[3] ) unless ( ref($lab)    eq "LML::Lab" );
    croak( "2nd argument must be an instance of LML::Config called at " . ( caller 0 )[3] ) unless ( ref($config) eq "LML::Config" );

    my $self = {
                 lab     => $lab,
                 config  => $config,
                 verbose => $config->get( "lml", "verbose_auto_placement" ),
    };

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host, $vm_res, $error_ref ) = @_;
    return 0 unless ( defined $host->{name} );    # gracefully skip hosts without data.
    $error_ref = [] unless (defined $error_ref and ref($error_ref) eq "ARRAY");
    my @network_labels_provided_host = $self->_get_network_labels_provided_by($host);

    foreach my $label ( @{ $vm_res->{networks} } ) {
        if ( !$self->_host_provides_network( $label, @network_labels_provided_host ) ) {
            push @$error_ref, "Host $host->{name} does not have the '$label' network";
            if ( $self->{verbose} ) {
                print STDERR "Removing host " . $host->{name} . " because it has no $label network\n";
            }
            return 0;
        }
    }

    return 1;
}

sub get_name {
    return 'ByNetworks';
}

sub _host_provides_network {
    my ( $self, $network_label, @provided_network_labels ) = @_;
    return 1 if ( grep { /^$network_label/ } @provided_network_labels );
    return 0;
}

sub _get_network_labels_provided_by {
    my ( $self, $host ) = @_;
    return map { $self->{lab}->{NETWORKS}->{$_}->{name} } @{ $host->{networks} };
}

1;
