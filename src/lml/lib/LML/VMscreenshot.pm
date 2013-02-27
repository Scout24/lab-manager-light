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

use GD;

sub new {
    my ( $class, $config, $uuid ) = @_;
    croak( "1st parameter to " . ( caller(0) )[3] . " must be a LML::Config object" )
      unless ( ref($config) eq "LML::Config" );
    croak( "2nd parameter to " . ( caller(0) )[3] . " must be a scalar" ) unless ( ref($uuid) eq "" );
    my $self = {
            config   => $config,
            uuid     => $uuid,
            push_max => ( $config->get( "vmscreenshot", "push_max" ) ? $config->get( "vmscreenshot", "push_max" ) : 0 ),
    };
    my $LAB = new LML::Lab( $config->labfile );
    my $HOST = $LAB->get_host($uuid);
    if ( $HOST and exists $HOST->{VM_ID}) {
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
            GET => ( $ENV{VI_SERVER} =~ m#://# ? "" : "https://" ) . $ENV{VI_SERVER} . "/screen?id=" . $self->{vm_id} );
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
    if (ref($q) !~ m/^CGI/ ) {
        croak( "1st parameter to " . ( caller(0) )[3] . " must be CGI object and not " . ref($q) )
    }
    my $gd = new GD::Image($self->png) or croak("new GD failed");
    my $black = $gd->colorAllocate(0,0,0);
    my $white = $gd->colorAllocate(255,255,255);
    Debug("page count $counter");
    if ( $counter <= $self->{push_max} ) {
        my $last = $counter == $self->{push_max};

        # add time stamp
        my $width = $gd->width;
        my $height = $gd->height;
        if ($height > 200 and $width > 300) {
            # if image is large enough to write on it then we do it.
            my $font = GD::Font->Small;
            my $text = POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime );
            my $margin = 5;
            # this is the space that the actual text needs.
            my ($textwidth,$textheight) = (length($text) * $font->width, $font->height); 
            # add the margin to get the dimensions of the frame
            my ($framewidth,$frameheight) = ($textwidth+2*$margin,$textheight+2*$margin); 
            # paint white frame filled black in upper right corner, the +1 and -1 shift the
            # frame by one pixel to NE so that the upper and the right line disappear
            $gd->filledRectangle($width - $framewidth + 1,-1,$width,$frameheight,$black);
            $gd->rectangle($width - $framewidth + 1,-1,$width,$frameheight,$white);
            $gd->string($font, $width - $margin - $textwidth, $margin, $text, $white);
        }
        
        if ($last) {
            my $font = GD::Font->Giant;
            my $text = "Click to restart streaming";
            my $margin = 10;
            # this is the space that the actual text needs.
            my ($textwidth,$textheight) = (length($text) * $font->width, $font->height); 
            # add the margin to get the dimensions of the frame
            my $frameheight = $textheight+2*$margin; 
            # paint black bar with white lines above and below
            # -1 and +1 make the left and right line disappear
            my $framey = int($height/2 - $frameheight/2);
            $gd->filledRectangle(0,$framey,$width,$framey+$frameheight,$black);
            $gd->rectangle(-1,$framey,$width+1,$framey+$frameheight,$white);
            $gd->string($font, int($width/2 - $textwidth/2), $framey + $margin, $text, $white);
        }
        my $png = $gd->png;
        return $q->header( ($last ? (-LML_Page => "last") : () ),  -Content_Type => "image/png", -Content_Length => length($png), -expires => "now" )
          . $png;
    } else {
        Debug( "reached max push of " . $self->{push_max} );
        return undef;
    }
}

1;
