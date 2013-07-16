package LML::Config;

use strict;
use warnings;
use Carp;
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

sub get_array {
    # return list, even if only single item
    my ( $self, $section, $key ) = @_;
    # config sections and keys are always lowercase.
    $section = lc $section;
    $key     = lc $key;
    my @raw_value = ();
    if ( exists( $self->{$section}->{$key} ) ) {
        @raw_value = ref( $self->{$section}->{$key} ) eq "ARRAY" ? @{ $self->{$section}->{$key} } : ( $self->{$section}->{$key} );
    }
    Debug("Config->get_array($section,$key) at ".( caller(0) )[1].":".( caller(0) )[2]." = ".join(", ",@raw_value ? @raw_value : ("<empty array>")));
    return @raw_value;
}

sub get {
    # return string, multi-line values will be concatenated with newlines
    my ( $self, $section, $key ) = @_;
    # config sections and keys are always lowercase.
    $section = lc $section;
    $key     = lc $key;
    my $raw_value = undef;
    if ( exists( $self->{$section}->{$key} ) ) {
        $raw_value = ref( $self->{$section}->{$key} ) eq "ARRAY" ? join("\n",@{ $self->{$section}->{$key} }) : $self->{$section}->{$key};
    }
    Debug("Config->get($section,$key) at ".( caller(0) )[1].":".( caller(0) )[2]." = ".(defined($raw_value) ? $raw_value : "<undef>"));
    return $raw_value;
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

sub appenddomain {
    # get the appenddomain for given network.
    my ( $self, $network ) = @_;
    $network = "" unless ($network);    # network is optional
    return exists( $self->{"appenddomains"}->{$network} ) ? $self->{"appenddomains"}->{$network} : $self->{"dhcp"}->{"appenddomain"};
}

sub vsphere_networks {
   confess("Not implemented");
}

1;
