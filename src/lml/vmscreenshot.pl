#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI::Push;
use LML::Config;
use LML::VMscreenshot;
use LWP::UserAgent;

# main() code when running as stand-alone program
unless (caller) {
    my $C = new LML::Config();
    my $result;
    my $q = new CGI::Push;
    if ( $C->get( "vmscreenshot", "enabled" ) ) {
        # input parameter, UUID of a VM
        if ( my $search_uuid = $q->param('uuid') ) {
            $search_uuid = lc( $q->param('uuid') );
            if ( my $screenshot = new LML::VMscreenshot( $C, $search_uuid ) ) {
                # we could load the VM data from LAB, return image data or HTML document
                if ( $q->Accept("image/png") >= 0.9 or $q->param('image') ) {
                    if ( $q->param("stream") ) {
                        $q->do_push(
                                     -type      => "dynamic",
                                     -nph       => 0,
                                     -delay     => $C->get( "vmscreenshot", "push_delay" ),
                                     -next_page => sub { return $screenshot->render(@_) } );
                    } else {
                        binmode STDOUT; # don't let anybody mess with our output
                        print $screenshot->render( $q, -1 );    # -1 should always be smaller than the max_push parameter
                    }
                } else {
                    print( $q->header,
                           $q->start_html( "LML VM Screenshot of " . $screenshot->hostname ),
                           $q->img( {
                                      -style   => "cursor: pointer;",
                                      -onclick => "this.src=this.src+'&'+Math.random()",
                                      -title   => "Click to reload screenshot",
                                      -src     => $q->url( -relative => 1, -query => 1 ) }
                           ),
                           $q->end_html
                    );
                }
            } else {
                # No data found
                print( $q->header( -status => "404 No data found" ),
                       $q->start_html("LML Error"),
                       $q->h1("LML Error"), $q->p("No data found for $search_uuid."),
                       $q->end_html );
            }

        } else {
            # no uuid parameter given
            print( $q->header( -status => "404 No uuid given" ),
                   $q->start_html("LML Error"),
                   $q->h1("LML Error"), $q->p("No uuid= parameter given."),
                   $q->end_html );
        }
    } else {
        # disabled
        print( $q->header( -status => "403 VM screenshots disabled" ),
               $q->start_html("LML Error"),
               $q->h1("LML Error"), $q->p("VM screenshots disabled."),
               $q->end_html );
    }
}
