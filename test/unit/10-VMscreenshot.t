use strict;
use warnings;

use File::Slurp;
use Test::More;
use Test::Warn;
use Test::Exception;
use Text::Diff;
use CGI;
use Cwd;
use Data::Dumper;

use LML::Config;
# mock needed function from LML::VMware
use Test::MockModule;
use LML::VMware;
my $mock = new Test::MockModule('LML::VMware');
my $VM_ALL = {
    "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" => {
                                                "CUSTOMFIELDS" => {
                                                                    "Contact User ID" => "User2",
                                                                    "Expires"         => "31.01.2013",
                                                                    "Force Boot"      => ""
                                                },
                                                "EXTRAOPTIONS" => { "bios.bootDeviceClasses" => "allow:net" },
                                                "MAC"          => {
                                                           "01:02:03:04:6e:4e" => "arc.int",
                                                           "01:02:03:04:9e:9e" => "foo"
                                                },
                                                "NAME"       => "tsthst001",
                                                "HOST"       => "testesx01.domain",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "01:02:03:04:6e:4e",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "01:02:03:04:9e:9e",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                                "PATH"  => "development/vm/otherpath/tsthst001",
                                                "VM_ID" => "vm-1000",
                                                "UUID"  => "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf"
    },
};

$mock->mock(
    'get_vm_data',
    sub {
        my $uuid = shift;
        #diag("Mock get_vm_data($uuid):\n");
        return \() unless ( exists $VM_ALL->{$uuid} );
        return $VM_ALL->{$uuid};

    } );

use_ok "LML::VMscreenshot";

my @conffiles = ( "src/lml/default.conf", "test/data/test.conf" );
dies_ok { new LML::VMscreenshot } "Should die with parameter error (no parms)";
# TODO: find out why this fails in mock build:
# dies_ok { new LML::VMscreenshot( new LML::Config(@conffiles) ) } "Should die with parameter error (only 1 parm)";
is( new LML::VMscreenshot( new LML::Config(@conffiles), "abcd" ), undef, "New object with invalid uuid should be undef" );

my $C = new LML::Config(@conffiles);
# test/data/screen should be a PNG file
$ENV{VI_SERVER} = "file://" . cwd() . "/test/data";
my $screenshot = new_ok( "LML::VMscreenshot" => [ $C, "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" ],
                         "Should return object" );
my $png_re = qr(\o{211}PNG\r\n\o{032}\n\0\0\0\rIHDR.*\o{202})s;
like( $screenshot->png, $png_re, "Should return something like png" );

my $first_page_render_response = $screenshot->render( new CGI, -1 );
like ($first_page_render_response, qr(Expires:.*\r\n\r\n)s,"first page should set Expires header");
like ($first_page_render_response, qr(Date:.*\r\n\r\n)s,"first page should set Date header");
like ($first_page_render_response, qr(Content-length: \d+.*\r\n\r\n)s,"first page should set Content-length header with a number");
like ($first_page_render_response, qr(Content-Type: image/png.*\r\n\r\n)s,"first page should set Content-Type: image/png header");
like( $first_page_render_response, qr(${png_re})s, "first page should contain PNG image");

is( $screenshot->render( new CGI, 100000 ), undef, "render should return undef if requested page is larger that push_max" );

my $last_page_render_response = $screenshot->render( new CGI, 25 );
like ($last_page_render_response, qr(Expires:.*\r\n\r\n)s,"last page should set Expires header");
like ($last_page_render_response, qr(Lml-page: last.*\r\n\r\n)s,"last page should set Lml-page: last header");
like ($last_page_render_response, qr(Content-Type: image/png.*\r\n\r\n)s,"last page should set Content-Type: image/png header");
like ($last_page_render_response, qr(${png_re})s, "last page should contain PNG image");

done_testing();
