package LML::Validation;

use strict;
use warnings;

use CGI qw/param/;

use Exporter;
use vars qw(
  @EXPORT_OK
);

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
  validate_cgi
  validate
  validate_with
  validate_with_any
  validate_with_all

  $VALIDATE_HOSTNAME
  $VALIDATE_FQDN
  $VALIDATE_USERNAME
  $VALIDATE_ONE_LINE
  $VALIDATE_NO_PARENT_LINKS
  $VALIDATE_ABS_PATH
  $VALIDATE_INTEGER
  $VALIDATE_NUMBER
  $VALIDATE_IPV4
  $VALIDATE_CIDR
  $VALIDATE_UUID
  $VALIDATE_GER_DATE
);


our $VALIDATE_HOSTNAME = qr/^[a-z0-9\-]+$/;
our $VALIDATE_FQDN     = qr/^(?:[a-z0-9\-]+\.)*[a-z0-9\-]+$/;
our $VALIDATE_USERNAME = qr/^[a-z_][a-z0-9\-_]+$/;
our $VALIDATE_ONE_LINE = sub {
  my $value = shift;
  return $value !~ /[\r\n]/;
};
our $VALIDATE_NO_PARENT_LINKS = sub {
  my $value = shift;
  return $value !~ /\/\.\.\//;
};
our $VALIDATE_ABS_PATH = sub {
  my $value = shift;
  return $value =~ /^\//
    && $VALIDATE_ONE_LINE->($value)
    && $VALIDATE_NO_PARENT_LINKS->($value);
};
our $VALIDATE_INTEGER  = qr/^[0-9]+$/;
our $VALIDATE_NUMBER   = qr/^[0-9]+(?:\.[0-9]+)?$/;
our $VALIDATE_IPV4     = qr/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/;
our $VALIDATE_CIDR     = qr/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$/;
our $VALIDATE_UUID     = qr/^[0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12}$/;
our $VALIDATE_GER_DATE = qr/^[0123]?[0-9]\.[01]?[0-9]\.(?:19|20)[0-9]{2}$/;


# validate_params extracts all params specified in validation specification
# and delegates them to validate
sub validate_params {
  my ($spec) = @_;
  my %data;
  foreach my $key(sort keys %$spec) {
    my $value = param($key);
    next unless $value;
    $data{$key} = $value;
  }

  return validate(\%data, $spec);
}

# validate_cgi extracts all params from given CGI::Push object as specified in
# validation specification and delegates them to validate
sub validate_cgi {
  my ($cgi, $spec) = @_;
  my %data;
  foreach my $key(sort keys %$spec) {
    my $value = $cgi->param($key);
    next unless $value;
    $data{$key} = $value;
  }

  return validate(\%data, $spec);
}

# validate takes hashref of containing input data and hashref of validation
# specification and checks each input value against validation.
# returns hashref of valid with {key => value} and hashref of invalid with {key => [value]}
sub validate {
  my ($data, $spec) = @_;
  my (%validated, %invalid);
  foreach my $key(sort keys %$data) {
    next unless defined $spec->{$key};
    my $value     = $data->{$key};
    my $validator = $spec->{$key};

    if (defined validate_with($value, $validator)) {
      $validated{$key} = $value;
    } else {
      $invalid{$key} = [$value];
    }
  }

  return \%validated, \%invalid;
}

# validate_with validates given value with given validator. validator
# can either be code(-ref) of the form `sub {my $v = shift; return $v eq ".."}`
# or array with allowed values or regexp-matcher or scalar which is the same as
# a single-item array.
# returns value itself or undef if validation failed.
sub validate_with {
  my ($value, $validator) = @_;
  my $type = ref($validator);

  if ($type =~ /^CODE/) {
    return $validator->($value) ? $value : undef;

  } elsif ($type =~ /^ARRAY/) {
    my %ok = map {($_ => 1)} @$validator;
    return defined $ok{$value} ? $value : undef;

  } elsif ($type =~ /^Regexp/) {
    return $value =~ $validator ? $value : undef;

  } else {
    return $value eq "$validator" ? $value : undef;
  }
}

# validate_with_all validates given value against _ALL_ validators and only
# if _ALL_ match it returns value, otherwise undef
sub validate_with_all {
  my ($value, @validators) = @_;
  foreach my $validator(@validators) {
    return undef
      unless defined validate_with($value, $validator);
  }
  return $value;
}

# validate_with_any validates given value against all validators until first
# match, in which case value is returned. Only if non of the validators match
# undef is returend
sub validate_with_any {
  my ($value, @validators) = @_;
  foreach my $validator(@validators) {
    return $value
      if defined validate_with($value, $validator);
  }
  return undef;
}
