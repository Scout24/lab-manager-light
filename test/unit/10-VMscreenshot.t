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
dies_ok { new LML::VMscreenshot( new LML::Config(@conffiles) ) } "Should die with parameter error (only 1 parm)";
is( new LML::VMscreenshot( new LML::Config(@conffiles), "abcd" ), undef, "New object with invalid uuid should be undef" );

my $C = new LML::Config(@conffiles);
# test/data/screen should be a PNG file
$ENV{VI_SERVER} = "file://" . cwd() . "/test/data";
my $screenshot = new_ok( "LML::VMscreenshot" => [ $C, "4213038e-9203-3a2b-ce9d-c6dac1f2dbbf" ],
                         "Should return object" );
my $png_re = qr(\211PNG\r\n\32\n\0\0\0\rIHDR.*\202)s;
like( $screenshot->png, $png_re, "Should return something like png" );
like( $screenshot->render( new CGI, -1 ),
      qr(Expires:.*Date.*Content-length:.*Content-Type: image/png; charset=ISO-8859-1\r\n\r\n${png_re})s,
      "should return HTTP response with PNG like in it" );
is( $screenshot->render( new CGI, 100000 ), undef, "render should return undef if requested page is larger that push_max" );
like( $screenshot->render( new CGI, 25 ),
      qr(Expires:.*Date.*Content-length:.*Lml-page: last\r\nContent-Type: image/png; charset=ISO-8859-1\r\n\r\n${png_re})s,
      "should return  last HTTP response with png in it" );
done_testing();
