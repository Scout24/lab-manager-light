package TestTools::VMcreated;

use strict;
use warnings;

use TestTools::QRdata;
use LWP::UserAgent;
use HTTP::Request;
use Time::HiRes qw(sleep time);
use JSON;

use TeamCity::Messages;
my $screenshot_interval = 10;    # take a screenshot every 10 seconds

sub new {
    my ( $class, $uuid, $vm_create_options ) = @_;

    my $self = {
                 uuid              => $uuid,
                 vm_create_options => $vm_create_options,
    };

    bless $self, $class;

    return $self;
}

sub load_qrdata {
    my ($self) = @_;

    my $starttime = time;
    my $vm_spec;
    my $file;
    my $screenshot_count = 0;

    while ( not $vm_spec and ( time() <= $starttime + $self->{vm_create_options}->{boot_timeout} ) ) {
        $screenshot_count++;
        my $last = time();
        $file = $self->_download_vm_screenshot( $self->{uuid}, $screenshot_count );
        $vm_spec = $self->_decode_qr($file);
        my $sleep_time = $screenshot_interval - ( time() - $last );    # the remaining time till the screenshot interval
        sleep($sleep_time) if ( $sleep_time > 0 );                     # be nice to vSphere and try again only after a few seconds
    }
    my $short_file_basename = "test/temp/" . $self->{vm_create_options}->{name} . "_" . $self->{uuid};
    my $out = qx(convert -delay 20 -page 800x600 -dispose background $short_file_basename*.png -loop 1 $short_file_basename.gif 2>&1);
    teamcity_build_progress("convert failed:\n$out") if ( ( $? >> 8 ) > 0 );
    link $file, $short_file_basename . ".png";

    unless ($vm_spec) {
        $self->_fail_team_city_build( "No QR code recognized after " . $self->{vm_create_options}->{boot_timeout} . " seconds" );
    }

    return new TestTools::QRdata( $self->{uuid}, $vm_spec, $self->{vm_create_options} );
}

sub match_ocr {
    my ( $self, $test_definition ) = @_;

    my $starttime = time;
    my $test_passed;
    my $error_data;
    my $file;
    my $screenshot_count = 0;
    my $error_count = 0;

    while ( ( not $test_passed or $test_passed == -1 ) and ( time() <= $starttime + $self->{vm_create_options}->{boot_timeout} ) ) {
        $screenshot_count++;
        my $last = time();
        $file = $self->_download_vm_screenshot( $self->{uuid}, $screenshot_count );
        ($test_passed, $error_data) = $self->_ocr_match( $file, $test_definition );
        # Revalidate the error (because packagename with
        # error or package descriptions will match as well)
        if ( $test_passed == -1 ) {
            if ( $error_count ) {
                teamcity_build_failure("OCR scan found error:\n$error_data");
                die "OCR found failure";
            } else {
                teamcity_build_progress("OCR scan found first error, retrying:\n$error_data");
                $error_count++;
            }
        }
        my $sleep_time = $screenshot_interval - ( time() - $last );    # the remaining time till the screenshot interval
        sleep($sleep_time) if ( $sleep_time > 0 );                     # be nice to vSphere and try again only after a few seconds
    }
    my $short_file_basename = "test/temp/" . $self->{vm_create_options}->{name} . "_" . $self->{uuid};
    my $out = qx(convert -delay 20 -page 800x600 -dispose background $short_file_basename*.png -loop 1 $short_file_basename.gif 2>&1);
    teamcity_build_progress("convert failed:\n$out") if ( ( $? >> 8 ) > 0 );
    link $file, $short_file_basename . ".png";

    unless ($test_passed) {
        $self->_fail_team_city_build( "No OCR match after " . $self->{vm_create_options}->{boot_timeout} . " seconds" );
    }

    return $test_passed;
}

#####################################################################
#####################################################################
# PRIVATE FUNCTIONS
#####################################################################
#####################################################################

# downloads VM screenshot and saves it in a file and return file name
sub _download_vm_screenshot {
    my ( $self, $uuid, $screenshot_count ) = @_;
    my $file = sprintf( "test/temp/%s_%s_%03d.png", $self->{vm_create_options}->{name}, $self->{uuid}, $screenshot_count );
    my $url = sprintf( "http://%s/lml/vmscreenshot.pl?image=1&uuid=%s", $self->{vm_create_options}->{test_host}, $self->{uuid} );

    teamcity_build_progress("Downloading VM Screenshot from $url to $file");
    my $png = $self->_do_http_get_request($url);

    open my $FILE, ">$file" or $self->_fail_team_city_build("Could not open $file for writing");
    print $FILE $png or $self->_fail_team_city_build("Could not write to $file");
    close $FILE;
    return $file;
}

# logs TeamCity build status message with FAILURE status
sub _fail_team_city_build {
    my ( $self, $reason ) = @_;
    teamcity_build_failure($reason);
    die "An error occured while creating vm:\n$reason";
}

sub _do_http_get_request {
    my ( $self, $url ) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->agent("lml-system-test ");
    my $req = HTTP::Request->new( GET => "$url" );

    my $res = $ua->request($req);
    return $res->is_success ? $res->content : "ERROR: " . $res->status_line;
}

# decodes the QR code
# returns a hash with decoded vm specification, or undefined if no QR code
# identified in the picture
sub _decode_qr {
    my ( $self, $file ) = @_;

    print "##teamcity[progressMessage 'Decoding QR code from $file']\n";

    my $raw_data = qx(zbarimg -q --raw $file);
    if ( ( $? >> 8 ) > 0 ) {
        print "##teamcity[progressMessage 'Decoding of qr-code image failed.']\n";
    }
    #    return $raw_data ? decode_json($raw_data) : undef;
    return $raw_data;
}

sub _ocr_match {
    my ( $self, $file, $test_definition ) = @_;
    teamcity_build_progress("OCR scan on $file");

    my $raw_data = qx(gocr -m 2 -a 100 -d 0 -p test/system/lib/gocr_db/ $file);
    if ( ( $? >> 8 ) > 0 ) {
        return 0;
    }
    else {
        print "OCR text Result:\n" . $raw_data;
        my $match = 0;
        foreach my $pattern ( @{ $test_definition->{expect} } ) {
            teamcity_build_progress("Validating OCR text for matching pattern '$pattern'");
            $match += ( $raw_data =~ qr($pattern)ms ) ? 1 : 0;    # add 1 for matching patterns
        }
        if ( $match == 0 ) {
            # kickstart errors show up in negative
            my $error_data = qx(gocr -l 160 -m 2 -a 100 -d 0 -p test/system/lib/gocr_db/ $file);
            if ( $error_data =~ qr(error|failure)i ) {
                return (-1, $error_data)
            }
        }
        return $match;
    }

}
1;
