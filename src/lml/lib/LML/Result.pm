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
                 config          => $config,
                 status          => "200 OK",
                 errors          => [],
                 statusinfo      => "",
                 redirect_target => "",
                 full_url        => $full_url
    };

    bless( $self, $class );
    return $self;
}

sub add_error {
    my $self = shift;
    push( @{ $self->{errors} }, @_ );
    return $self->get_errors;
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

sub redirect_target {
    my $self = shift;
    return $self->{redirect_target};
}

sub get_errors {
    my $self = shift;
    return @{ $self->{errors} } if (wantarray);
    return scalar( @{ $self->{errors} } );    # return amount of errors in scalar context
}

sub render {
    my ( $self, @body ) = @_;
    my $status = $self->{status};
    if ( $self->{statusinfo} ) {
        $status .= " and " . $self->{statusinfo};
    }
    if ( $self->get_errors ) {
        $status .= ", Errors: " . join( ", ", $self->get_errors );
    }
    my $header_args = {
                        -status => $status,
                        -type   => 'text/plain'
    };

    if ( $self->{redirect_target} ) {
        my $redirect_base = $self->{full_url};
        if ( substr( $self->{redirect_target}, 0, 1 ) eq "/" ) {
                                                                    # redirect to absolute url on our host
            $redirect_base =~ s#^(.*://[^/]+).*$#$1#;              # strip everything after the host part
        } else {
            # redirect to relative url (probably to /boot/) on our host
            $redirect_base =~ s#pxelinux.cfg/.*$##;                 # strip pxelinux.cfg/*
        }
        $header_args->{-location} = $redirect_base . $self->{redirect_target};
    }
    return header($header_args) . join( "\n", @body );
}

1;
