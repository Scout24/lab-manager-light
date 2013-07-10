#!/usr/bin/perl -w

# required dependencies:
# zbar
# perl-libwww-perl
# perl-JSON

use strict;
use warnings;

use Getopt::Long;

use LWP::UserAgent;
use HTTP::Request;
use DateTime;

use JSON;

use constant MAX_QR_CODE_AGE_SEC => 180;    # 3 minutes

my $boot_timeout = 30;
my $test_host;
my $vm_name_prefix;
my $vm_number = generate_vm_number();
my $esx_host;
my $username;
my $expiration_date = DateTime->today()->add( days => 1 )->dmy(".");
my $folder;
my $force_boot_target = 'qrdata';
my $lmlhostpattern;
my $screenshot_count = 0;

my $vm_host;
print "##teamcity[buildStatus text='Running Integration Test']" . $/;

# processes build parameters
# sets the global variables
sub process_parameters {
    if (
        !GetOptions(
                     "boot_timeout=i"    => \$boot_timeout,
                     "test_host=s"       => \$test_host,
                     "vm_name_prefix=s"  => \$vm_name_prefix,
                     "esx_host=s"        => \$esx_host,
                     "username=s"        => \$username,
                     "expiration_date=s" => \$expiration_date,
                     "folder=s"          => \$folder,
                     "lmlhostpattern=s"  => \$lmlhostpattern,
        ) )
    {
        fail_team_city_build( "Missing options", "0" );
    }
    # make sure that everything is set
    if ( not( $test_host and $vm_name_prefix and $esx_host and $username and $folder and $lmlhostpattern ) ) {
        fail_team_city_build( "Need to provide at least test_host, vm_name_prefix, esx_host, username, folder and lmlhostpattern options.",
                              "0" );
    }
}

# generates a host number as a current minute
# because DHCP lease lasts 1 hour at us
sub generate_vm_number {
    my @time = localtime(time);
    my $time = $time[1] + 1;
    $time < 10 ? return "0$time" : return $time;
}

sub do_http_post_request {
    my $url  = shift;
    my $data = shift;

    my $ua = LWP::UserAgent->new;
    $ua->agent("TeamCity/0.1 ");

    my $req = HTTP::Request->new( POST => "$url" );
    $req->content_type("application/x-www-form-urlencoded");
    $req->content("$data");

    my $res = $ua->request($req);
    return $res->is_success ? $res->content : "ERROR: ".$res->status_line;
}

# creates a new vm
# returns UUID or error message
sub create_vm {
    report_progress("Creating $vm_host");
    return
      do_http_post_request(
        "http://$test_host/lml/restricted/vm-create.pl",
"name=$vm_host&esx_host=$esx_host&username=$username&expiration=$expiration_date&folder=$folder&force_boot_target=$force_boot_target"
      );
}

# deletes the vm
sub delete_vm {
    report_progress("Deleting $vm_host");
    return do_http_post_request( "http://$test_host/lml/restricted/vm-control.pl", "action=destroy&hosts=$vm_host" );
}

sub do_http_get_request {
    my $url = shift;
    my $ua  = LWP::UserAgent->new;
    $ua->agent("TeamCity/0.1 ");
    my $req = HTTP::Request->new( GET => "$url" );

    my $res = $ua->request($req);
    $res->is_success ? return $res->content : return $res->status_line;
}

# downloads VM screenshot and saves it in a file and return file name
sub download_vm_screenshot ($) {
    my $uuid = shift;
    my $file = "test/temp/" . $vm_host . "_" . $uuid . "_" . $screenshot_count++ . ".png";
    my $url  = "http://$test_host/lml/vmscreenshot.pl?image=1&uuid=$uuid";
    report_progress("Downloading VM Screenshot from $url to $file");
    my $png = do_http_get_request($url);
    open( FILE, ">$file" ) or fail_team_city_build("Could not open $file for writing","1");
    print FILE $png or fail_team_city_build("Could not write to $file","1");
    close(FILE);
    return $file;
}

# decodes the QR code
# returns a hash with decoded vm specification, or undefined if no QR code
# identified in the picture
sub decode_qr ($) {
    my $file = shift;
    report_progress("Decoding QR code from $file");
    my $raw_data = `zbarimg -q --raw $file`;
    return $raw_data ? decode_json($raw_data) : undef;
}

# asserts a single field in the vm specification
sub assert {
    my $spec     = shift;
    my $field    = shift;
    my $expected = shift;
    my $actual   = $spec->{"$field"};
    fail_team_city_build( "expected $field: $expected, actual: $actual", "1" ) if ( "$actual" ne "$expected" );
}

# asserts that the QR code is not too old
sub assert_qr_code_age {
    my $spec = shift;
    my $time = $spec->{"UPDATED"};
    fail_team_city_build( "QR code ".(time-$time)." seconds old, more than allowed ".MAX_QR_CODE_AGE_SEC, "1" ) if ( time - $time > MAX_QR_CODE_AGE_SEC );
}

# asserts the vm path
sub assert_vm_path {
    my $spec = shift;
    my $path = $spec->{"PATH"};
    fail_team_city_build( "expected path: $folder/$vm_host, actual $path", "1" ) if ( $path !~ /$folder\/$vm_host/ );
}

# assert the lml host
sub assert_lml_host {
    my $spec    = shift;
    my $lmlhost = $spec->{"LMLHOST"};
    fail_team_city_build( "expected LML host pattern $lmlhostpattern does not match $lmlhost", "1" ) if ( $lmlhost !~ /$lmlhostpattern/ );
}

# asserts the vm specification
sub assert_vm_spec {
    report_progress("Validating QR code");
    my $spec = shift;
    my $uuid = shift;

    assert_qr_code_age($spec);
    assert( $spec, "UUID",     $uuid );
    assert( $spec, "HOST",     $esx_host );
    assert( $spec, "HOSTNAME", $vm_host );
    assert_vm_path($spec);
    assert_lml_host($spec);

    my $custom_fields = $spec->{"CUSTOMFIELDS"};
    assert( $custom_fields, "Contact User ID", $username );
    assert( $custom_fields, "Expires",         $expiration_date );
}

# logs TeamCity build status message with FAILURE status
sub fail_team_city_build {
    my $reason = shift;
    print "##teamcity[buildStatus status='FAILURE' text='$reason']" . $/;
    delete_vm();
    exit 1;
}

# logs TeamCity build progress message
sub report_progress {
    my $message = shift;
    print "##teamcity[progressMessage '$message']" . $/;
}

process_parameters();
$vm_host = $vm_name_prefix . $vm_number;

my $uuid = create_vm();
if ( $uuid =~ /ERROR: / or $uuid =~ /\s+/ ) {
    fail_team_city_build( $uuid, "0" );
} else {
    my $starttime = time();
    my $vm_spec;
    my $file;
    while (not $vm_spec and (time() <= $starttime + $boot_timeout)) {
        $file = download_vm_screenshot($uuid);
        $vm_spec = decode_qr($file);
        sleep 3; # be nice to vSphere and try again only after a few seconds
    }
    if ($vm_spec) {
        link($file,"test/temp/".$vm_host."_".$uuid.".png");
        assert_vm_spec( $vm_spec, $uuid );
    } else {
        fail_team_city_build( "No QR code recognized", "1" );
    }
}

my $result = delete_vm();
chomp($result);
if ( $result ne "[\"$vm_host\"]" ) {
    fail_team_city_build( $result, "0" );
} else {
    print "##teamcity[buildStatus status='SUCCESS' text='Integration Test OK']" . $/;
}

