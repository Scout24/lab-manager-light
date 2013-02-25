package LML::VMscreenshot;

use strict;
use warnings;

use LML::VMware;
use LML::Common;
use CGI ':standard :push';

use CGI::Carp;
use LML::Config;
use LML::Common;
use LML::Lab;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;

use Image::Magick;

sub new {
    my ( $class, $config, $uuid ) = @_;
    croak( "1st parameter to " . ( caller(0) )[3] . " must be a LML::Common::Config object" )
      unless ( ref($config) eq "LML::Config" );
    croak( "2nd parameter to " . ( caller(0) )[3] . " must be a scalar" ) unless ( ref($uuid) eq "" );
    my $self = {
            config   => $config,
            uuid     => $uuid,
            push_max => ( $config->get( "vmscreenshot", "push_max" ) ? $config->get( "vmscreenshot", "push_max" ) : 0 ),
    };
    my $LAB = new LML::Lab( $config->labfile );
    if ( my $HOST = $LAB->get_host($uuid) ) {
        $self->{vm_id}    = $HOST->{VM_ID};
        $self->{hostname} = $HOST->{HOSTNAME};
    } else {
        Debug("No LAB data found for '$uuid'");
        return undef;    # signal no VM found
    }
    $self->{ua} = new LWP::UserAgent( keep_alive => 2 );    # get persistent LWP UA
    $self->{ua}->timeout(10);                               # 10 secs timeout
    $self->{ua}->env_proxy;

    bless( $self, $class );
    return $self;
}

sub hostname {
    my ($self) = @_;
    return $self->{hostname};
}

sub png {
    my ($self) = @_;
    my $ua = $self->{ua};
    my $request = new HTTP::Request(
            GET => ( $ENV{VI_SERVER} =~ m#::/# ? "" : "https://" ) . $ENV{VI_SERVER} . "/screen?id=" . $self->{vm_id} );
    $request->authorization_basic( $ENV{VI_USERNAME}, $ENV{VI_PASSWORD} );    # set credentials
    my $start_time = time;
    my $res        = $ua->request($request);
    Debug( "Request took " . ( time - $start_time ) . " seconds" );
    if ( $res->is_error ) {
        # return errors as something we can give the browser
        croak( $res->as_string );
    } elsif ( $res->is_success ) {
        return $res->content;                                                 # this should contain the raw image
    }
    croak( "Unknown LWP::UserAgent error: " . $res->status_line . "\n" );
    # we never should get here...
}

#
# use this to render via CGI ::Push
sub render {
    my ( $self, $q, $counter ) = @_;
    croak( "1st parameter to " . ( caller(0) )[3] . " must be CGI object and not " . ref($q) )
      unless ( ref($q) =~ m/^CGI/ );
    my $im = new Image::Magick( magick => "png" );
    croak("BlobToImage failed") unless ( $im->BlobToImage( $self->png ) == 1 );
    Debug("page count $counter");
    if ( $counter <= $self->{push_max} ) {
        my $e;
        # add time stamp
        $e = $im->Annotate(
                            pointsize => 10,
                            gravity   => "NorthEast",
                            antialias => "true",
                            undercolor => "black",
                            fill      => 'white',
                            text      => POSIX::strftime( " %Y-%m-%d %H:%M:%S ", localtime ) );
        croak("Annotate error: $e") if ($e);
        if ( $counter == $self->{push_max} ) {
            # last pic, add reload hint
            $e = $im->Annotate(
                                pointsize   => 40,
                                gravity     => "Center",
                                strokewidth => "2",
                                antialias   => "true",
                                stroke      => "white",
                                fill        => 'black',
                                text        => "Click to\nrestart streaming"
            );
        }
        my $png = ( $im->ImageToBlob )[0];
        return $q->header( -Content_Type => "image/png", -Content_Length => length($png), -expires => "now" )
          . $png;
    } else {
        Debug( "reached max push of " . $self->{push_max} );
        return undef;
    }
}

1;
