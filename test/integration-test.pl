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

use JSON;

use constant MAX_QR_CODE_AGE_SEC => 180;  # 3 minutes

my $test_host;
my $vm_loctyp;
my $vm_number = generate_vm_number();
my $esx_host;
my $username;
my $expiration_date;
my $folder;
my $force_boot_target = 'qrdata';

 process_parameters();
 my $vm_host = $vm_loctyp.$vm_number;
 
my $uuid = create_vm();
if ($uuid =~ /ERROR: / or $uuid =~ /\s+/) {
        fail_team_city_build($uuid);
} else {
      my $response = call_pxelinux($uuid);
      wait_for_machine_boot();
      download_qr_code($uuid);
      my $vm_spec = decode_qr($uuid);
      delete_qr($uuid);
       if ($vm_spec ) {
              assert_vm_spec($vm_spec, $uuid);
       } else {
              fail_team_city_build("No QR code recognized");
       }
 }
 
my $result = delete_vm();
chomp($result);
if ($result ne "[\"$vm_host\"]") {
       fail_team_city_build($result);
}

# processes build parameters
# sets the global variables
sub process_parameters {
     if (!GetOptions(
                "test_host=s"     => \$test_host,
                "vm_loctyp=s"     => \$vm_loctyp,
                "esx_host=s"     => \$esx_host,
                "username=s"     => \$username,
                "expiration_date=s"       => \$expiration_date,
                "folder=s"        => \$folder
    )) {
           fail_team_city_build("Missing options");
           die ("Missing options");
    };
}

# generates a host number as a current minute
# because DHCP lease lasts 1 hour at us
sub generate_vm_number {
        my @time = localtime(time);
        $time[1] < 10 ? return "0$time[1]" : return $time[1];
}

sub do_http_post_request {
       my $url = shift;
       my $data = shift;
       
       my $ua = LWP::UserAgent->new;
       $ua->agent("TeamCity/0.1 ");

       my $req = HTTP::Request->new(POST => "$url");
       $req->content_type("application/x-www-form-urlencoded");
       $req->content("$data");

       my $res = $ua->request($req);
       $res->is_success ? return $res->content : return $res->status_line;
}
  
# creates a new vm
# returns UUID or error message  
 sub create_vm {
        report_progress("Creating $vm_host");
        return do_http_post_request("http://$test_host/lml/restricted/vm-create-old.pl",
              "name=$vm_host&esx_host=$esx_host&username=$username&expiration=$expiration_date&folder=$folder&force_boot_target=$force_boot_target");
 } 
 
# deletes the vm
sub delete_vm {
        report_progress("Deleting $vm_host");
        return do_http_post_request("http://$test_host/lml/restricted/vm-control.pl",
              "action=destroy&hosts=$vm_host");
 }
 
# waits for the vm to boot
# not ideal, but simple solution
sub wait_for_machine_boot {
       report_progress("Waiting for $vm_host to boot");
       sleep 25;
}
 
sub do_http_get_request {
       my $url = shift;
       my $ua = LWP::UserAgent->new;
       $ua->agent("TeamCity/0.1 ");
       my $req = HTTP::Request->new(GET => "$url");

       my $res = $ua->request($req);
       $res->is_success ? return $res->content : return $res->status_line;
}
 
# calls pxelinux to update the lab.conf file
# should be unnecessary in future
sub call_pxelinux {
        report_progress("Calling pxelinux");
        my $uuid = shift;
        return do_http_get_request("http://$test_host/lml/pxelinux.pl?uuid=$uuid");
}
 
# downloads the QR code and saves it in a file
sub download_qr_code {
       report_progress("Downloading QR code");
       my $uuid = shift;
       my $png = do_http_get_request( "http://$test_host/lml/vmscreenshot.pl?image=1&uuid=$uuid");
       open(FILE, ">$uuid.png");
       print FILE  $png;
       close(FILE);
}
 
# decodes the QR code
# returns a hash with decoded vm specification, or undefined if no QR code 
# identified in the picture
sub decode_qr {
       report_progress("Decoding QR code");
       my $uuid = shift;
       my $raw = `zbarimg -q --raw $uuid.png`;
       return if ( ! $raw );
        
       my $return = decode_json($raw);
       return $return;
}

# deletes the QR code fil
sub delete_qr {
       report_progress("Deleting QR code file");
         my $uuid = shift;
       `rm $uuid.png`;
}

# asserts a single field in the vm specification
sub assert {
       my $spec = shift;
       my $field = shift;
       my $expected = shift;
       my $actual = $spec->{"$field"};
       fail_team_city_build("expected $field: $expected, actual: $actual")  if ("$actual" ne "$expected");
}

# asserts that the QR code is not too old
sub assert_qr_code_age {
       my $spec = shift;
       my $time = $spec->{"UPDATED"};
       fail_team_city_build("QR code too old") if (time - $time > MAX_QR_CODE_AGE_SEC);
}

# asserts the vm path
sub assert_vm_path {
       my $spec = shift;
       my $path = $spec->{"PATH"};
       fail_team_city_build("expected path: $folder/$vm_host, actual $path") if ($path !~ /$folder\/$vm_host/); 
}

# asserts the vm specification
sub assert_vm_spec {
       report_progress("Validating QR code");
       my $spec = shift;
       my $uuid = shift;
       
       assert_qr_code_age($spec);
       assert($spec,  "UUID", $uuid);
       assert($spec,  "HOST", $esx_host);
       assert($spec,  "HOSTNAME", $vm_host);
       assert_vm_path($spec);
       
       my $custom_fields = $spec->{"CUSTOMFIELDS"};
       assert($custom_fields, "Contact User ID", $username);
       assert($custom_fields, "Expires", $expiration_date);       
}
 
# logs TeamCity build status message with FAILURE status
sub fail_team_city_build {
        my $reason = shift;
        print "##teamcity[buildStatus status='FAILURE' text='$reason']".$/;
}

# logs TeamCity build progress message
sub report_progress {
       my $message = shift;
       print "##teamcity[progressMessage '$message']".$/;
}    
