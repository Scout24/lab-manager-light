package LML::Result;

use strict;
use warnings;

use CGI ':standard';
use LML::Config;
use Data::Dumper;
use Carp;

sub new {
    my ( $class, $config, $full_url ) = @_;

    croak( "1st parameter to " . ( caller(0) )[3] . " must be a LML::Common::Config object" ) unless ( ref($config) eq "LML::Config" );
    my $self = {
                 config          => $config,
                 status          => "200 OK",
                 errors          => [],
                 bootinfo        => "",
                 redirect_target => "",
                 full_url        => $full_url
    };

    bless( $self, $class );
    return $self;
}

sub add_error {
    my $self = shift;
    push( $self->{errors}, @_ );
    return $self->get_errors;
}

sub set_bootinfo {
    my ( $self, $bootinfo ) = @_;
    croak("1st parameter should be boot info") unless ($bootinfo);
    $self->{bootinfo} = $bootinfo;
    return $bootinfo;
}

sub set_redirect_target {
    my ( $self, $redirect_target ) = @_;
    croak("1st parameter should be redirect target") unless ($redirect_target);
    $self->{redirect_target} = $redirect_target;
    return $redirect_target;
}

sub get_errors {
    my $self = shift;
    return @{ $self->{errors} } if (wantarray);
    return scalar(@{ $self->{errors} }); # return amount of errors in scalar context
}

sub render {
    my $self   = shift;
    my $status = $self->{status};
    if ( $self->{errors} ) {
        $status .= ", Errors: " . join( ", ", @{ $self->{errors} } );
    }
    my $header_args = {
                        -status => $status,
                        -type   => 'text/plain'
    };

    if ( $self->{redirect_target} ) {
        my $redirect_base = $self->{full_url};
        $redirect_base =~ s#pxelinux.cfg/.*$##;    # strip pxelinux.cfg/*
        $header_args->{-location} = $redirect_base . $self->{redirect_target};
    }
    return header($header_args);
}

1;
