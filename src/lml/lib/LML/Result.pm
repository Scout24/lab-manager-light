package LML::Result;

use strict;
use warnings;

use CGI ':standard';
use LML::Config;
use Data::Dumper;
use Carp;

sub new {
    my ( $class, $config, $full_url ) = @_;

    croak( "1st parameter to " . ( caller(0) )[3] . " must be a LML::Common::Config object" )
      unless ( ref($config) eq "LML::Config" );
    my $self = {
                 config             => $config,
                 status             => "200 OK",
                 errors             => [],
                 statusinfo         => "",
                 redirect_target    => "",
                 redirect_parameter => "",
                 full_url           => $full_url
    };

    bless( $self, $class );
    return $self;
}

sub add_error {
    my $self = shift;
    push( @{ $self->{errors} }, @_ ) if (@_ and $_[0]);
    return @_;
}

sub set_statusinfo {
    my ( $self, $statusinfo ) = @_;
    croak("1st parameter should be status info\n") unless ($statusinfo);
    $self->{statusinfo} = $statusinfo;
    return $statusinfo;
}

sub set_status {
    my ( $self, @status ) = @_;
    croak("1st parameter should be status\n") unless ( scalar(@status) );
    $self->{status} = join( " ", @status );
    return $self->{status};
}

sub set_redirect_target {
    my ( $self, $redirect_target ) = @_;
    croak("1st parameter should be redirect target\n") unless ($redirect_target);
    $self->{redirect_target} = $redirect_target;
    return $redirect_target;
}

sub set_redirect_parameter {
    my ( $self, $redirect_parameter ) = @_;
    $self->{redirect_parameter} = $redirect_parameter;
    return $self->{redirect_parameter};
}

sub redirect_target {
    my $self = shift;
    return $self->{redirect_target};
}

sub get_errors {
    my $self = shift;
    return @{ $self->{errors} } if (wantarray);
    return scalar( @{ $self->{errors} } );    # return amount of errors in scalar context
}

sub get_full_url {
    # give full url as seen by HTTP client
    # this is needed by everything talking to pxelinux because pxelinux prepends the TFTP PREFIX to
    # relative URLs when used over HTTP.
    my ( $self, $url ) = @_;
    return "" unless($url);
    my $my_url = $self->{full_url};
    if ( $url =~ qr(://) ) {
        $my_url = "";
    } elsif ( $url =~ qr(^/) ) {
        # going to absolute url on our host
        $my_url =~ s#^(.*://[^/]+).*$#$1#;    # strip everything after the host part
    } else {
        # going to relative url (probably to /boot/) on our host
        $my_url =~ s#pxelinux.cfg/.*$##;      # strip pxelinux.cfg/*
    }
    return $my_url . $url;
}

sub render {
    my ( $self, @body ) = @_;
    my $status = $self->{status};
    if ( $self->{statusinfo} ) {
        $status .= " and " . $self->{statusinfo};
    }
    if ( $self->get_errors ) {
        $status .= ", Errors: " . join( ", ", $self->get_errors );
        $self->{redirect_target} = "";        # clear redirect target in case of errors
    }
    my $header_args = {
                        -status => $status,
                        -type   => 'text/plain'
    };

    if ( $self->{redirect_target} ) {
        # compose the paramter string (hostname is always present)
        my $parameter = '?';
        foreach ( keys( %{ $self->{redirect_parameter} } ) ) {
            $parameter .= $_ . '=' . ${ $self->{redirect_parameter} }{$_} . '&';
        }
        # remove the last ampersand
        chop($parameter);
        $header_args->{-location} = $self->get_full_url( $self->{redirect_target}) . $parameter;
    }
    return header($header_args) . join( "\n", @body );
}

1;
