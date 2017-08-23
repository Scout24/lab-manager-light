package LML::Debug;

use strict;
use warnings;

use Sys::Syslog;
use JSON qw/encode_json/;
use CGI qw/param/;
use Exporter;

our @ISA    = qw/Exporter/;
our @EXPORT = qw/log_request log_validation_fail/;

my $syslog_opened = 0;


sub log_message {
  my ($message) = @_;
  $syslog_opened++ || openlog("lab-manager-light", 'nofatal', 'user');
  syslog(info => $message);
}


sub log_request {
  return unless defined $ENV{REQUEST_METHOD};
  log_message(generate_request_message());
}


sub log_validation_fail {
  my ($key, $value) = @_;
  my $data     = ref($key) ? $key : {$key => $value};
  my $message = "Validation failed for ". encode_json($data);
  $message .= defined $ENV{REQUEST_METHOD}
    ? ", ". generate_request_message()
    : ", from command line ($0)";
  $message .= ", Origin: ". join(" -> ", (caller())[1..2]);
  log_message($message);
}


sub generate_request_message {
  my $params  = extract_request_params();
  return "Script: ". ($ENV{SCRIPT_NAME} // "-no-script-"). ", Method: ". ($ENV{REQUEST_METHOD} // "-no-method-"). ", Params: ". encode_json($params);
}


sub extract_request_params {
  return {map {
    ($_ => param($_))
  } param()};
}


1;
