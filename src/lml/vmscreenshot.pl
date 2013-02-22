#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Config;
use LML::Common;
use LML::Lab;
use Carp;

use LWP::UserAgent;
use HTTP::Request;

# uuid is either "" or undef to denote everything
sub retrieve_vm_screenshot {
    my ( $config, $uuid ) = @_;
    croak( "1st parameter must be LML::Config object in " . ( caller(0) )[3] ) unless ( ref($config) eq "LML::Config" );
    croak( "2nd parameter must be VM uuid in " . ( caller(0) )[3] ) unless ( ref($uuid) eq "" and $uuid );

    my $LAB = new LML::Lab( $config->labfile );

    if ( my $HOST = $LAB->get_host($uuid) ) {
        if ( my $vm_id = $HOST->{VM_ID} ) {
            my $ua = new LWP::UserAgent();
            $ua->timeout(10);    # 10 secs timeout
            $ua->env_proxy;
            my $request = new HTTP::Request( GET => "https://" . $ENV{VI_SERVER} . "/screen?id=" . $vm_id );
            $request->authorization_basic( $ENV{VI_USERNAME}, $ENV{VI_PASSWORD} );    # set credentials
            my $res = $ua->request($request);
            if ( $res->is_error ) {
                # return errors as something we can give the browser
                return new HTTP::Response( $res->code, $res->message, new HTTP::Headers( "Content-Type" => "text/html" ), $res->error_as_HTML );
            } elsif ( $res->is_success ) {
                return $res;
            } else {
                croak( "Unknown LWP::UserAgent error: " . $res->status_line . "\n" );
            }

        }
    }
    return new HTTP::Response( 404, "No VM found", new HTTP::Headers( "Content-Type" => "text/html" ), "<html><body>ERROR: No VM found</body></html>" );
}

# main() code when running as stand-alone program
unless (caller) {
    my $C = new LML::Config();
    my $result;
    if ( $C->get( "lml", "vmscreenshot" ) ) {
        # input parameter, UUID of a VM
        my $search_uuid;
        my $response;
        if ( param('uuid') ) {
            $search_uuid = lc(param('uuid'));
        } elsif (@ARGV) {
            $search_uuid = lc( $ARGV[0] );
        } else {
            $search_uuid = undef;                                                                                                                                           # use this to denote everything
            $response = new HTTP::Response( 404, "No uuid given", new HTTP::Headers( "Content-Type" => "text/html" ), "<html><body>ERROR: No UUID given</body></html>" );
        }

        if ($search_uuid) {
            if ( Accept("image/png") >= 0.9 ) {
                $response = retrieve_vm_screenshot( $C, $search_uuid );
            } else {
                # no image wanted, give HTML wrapper
                my $onclick = <<EOF;
                onclick="this.src=this.src+'&'+Math.random()"
EOF
                $onclick = "onclick='this.src=this.src;'";
                $response = new HTTP::Response( 200, "OK", new HTTP::Headers( "Content-Type" => "text/html" ), "<html><body><img style='cursor: pointer;' $onclick src='" . url( -relative => 1, -query => 1 ) . "'/></body></html>" );
            }
        }
        my %header_args = (
                            -status        => $response->status_line,
                            -type          => $response->header("Content-Type"),
                            -Cache_Control => "no-cache, no-store, must-revalidate",
                            -Pragma        => "no-cache",
                            -expires       => "10s" # takes 3 sec to load, prevent F5 DDOS
        );
        if ( $response->header("Content-Length") ) {
            $header_args{"-Content-Length"} = $response->header("Content-Length");
        }
        print header(%header_args);
        print $response->content;

    }
    exit( $result ? 0 : 1 );                                            # report status as exit code
}
