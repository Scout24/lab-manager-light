package LML::Config;

use strict;
use warnings;

use LML::Common;

sub new {
    my $class = shift;
    my $self;
    if ( ref( $_[0] ) eq "LML::Config" ) {
        confess("cloning LML::Config is not yet implemented, sorry.");
    } elsif ( ref( $_[0] ) eq "HASH" ) {
        $self = shift;
    } else {
        my %C = LoadConfig(@_);
        $self = \%C;
    }
    bless( $self, $class );
    return $self;
}

sub get {
    my ( $self, $section, $key ) = @_;
    if ( exists( $self->{$section}->{$key} ) ) {
        return $self->{$section}->{$key};
    } else {
        return undef;
    }
}

sub set {
    my ( $self, $section, $key, $value ) = @_;
    $self->{$section}->{$key} = $value;
    return $value;
}

sub get_proxy_parameter {
    my ( $self, %args ) = @_;
    my %parameters;
    # get a copy of the sub hash from "proxy_variables" configuration
    %parameters = %{ $self->{proxy_variables} } if exists $self->{proxy_variables};
    # append the hostname parameter
    $parameters{hostname} = $args{hostname};
    # return the hash reference
    return \%parameters;
}

sub labfile {
    my $self = shift;
    # TODO deal with the get() returning undef
    return $self->get( "lml", "datadir" ) . "/lab.conf";
}

sub vsphere_networks {
    my $self                    = shift;
    my @vsphere_networks        = ();                                    # list of network names for which LML is responsible.
    my $config_vsphere_networks = $self->get( "vsphere", "networks" );
    if ($config_vsphere_networks) {
        if ( ref($config_vsphere_networks) eq "ARRAY" ) {
            @vsphere_networks = @{$config_vsphere_networks};
        } else {
            @vsphere_networks = ($config_vsphere_networks);
        }
    } else {
        @vsphere_networks = (".*");                                      # match all networks if not configured
    }
    return @vsphere_networks;
}

1;
