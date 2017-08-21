use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Data::Dumper;

use_ok "LML::Validation";

my %SPECS = (
  'array' => {
    key => ['foo baz', 'bar baz']
  },
  'code' => {
    key => sub {
      my ($value) = @_;
      $value = lc($value);

      return $value eq 'foo baz' || $value eq 'bar baz';
    }
  },
  'regexp' => {
    key => qr/(foo|bar) baz/
  },
  'scalar' => {
    'key' => 'foo baz',
  }
);


my %EXPECTATIONS = (
  "foo baz" => {regexp => 1, array => 1, code => 1, scalar => 1},
  "bar baz" => {regexp => 1, array => 1, code => 1, scalar => 0},
  "BAR BAZ" => {regexp => 0, array => 0, code => 1, scalar => 0},
  "bla bla" => {regexp => 0, array => 0, code => 0, scalar => 0},
);


ok(defined LML::Validation::validate_with("foo", "foo"), "Scalar validation works");
ok(!defined LML::Validation::validate_with("foo", "bar"), "Inverted scalar validation works");

ok(defined LML::Validation::validate_with("foo", qr/oo/), "Regexp validation works");
ok(!defined LML::Validation::validate_with("foo", qr/aa/), "Inverted regexp validation works");

ok(defined LML::Validation::validate_with("foo", sub {return shift eq "foo"}), "Code validation works");
ok(!defined LML::Validation::validate_with("bar", sub {return shift eq "foo"}), "Inverted code validation works");

ok(defined LML::Validation::validate_with("foo", ["foo", "bar"]), "Array validation works");
ok(!defined LML::Validation::validate_with("baz", ["foo", "bar"]), "Inverted array validation works");

ok(defined LML::Validation::validate_with_all("foo", qr/f/, qr/o/, qr/foo/), "OK if ALL validators match");
ok(!defined LML::Validation::validate_with_all("foo", qr/f/, qr/o/, qr/a/), "Not ok if ANY validators do not match");

ok(defined LML::Validation::validate_with_any("foo", qr/baz/, qr/bar/, qr/foo/), "OK if any validator matches");
ok(!defined LML::Validation::validate_with_any("foo", qr/baz/, qr/bar/, qr/bla/), "Not OK if no validators matches");

ok(defined LML::Validation::validate_with(undef, ''), "Undef is empty");


foreach my $value(sort keys %EXPECTATIONS) {
  my %data = (key => $value);
  foreach my $validator(sort keys %{$EXPECTATIONS{$value}}) {
    my $expect_valid = $EXPECTATIONS{$value}->{$validator};
    my ($valid, $invalid) = LML::Validation::validate(\%data, $SPECS{$validator});
    #print Dumper({$validator => {VALID => $valid, INVALID => $invalid}});
    is(scalar keys %$valid, $expect_valid, "Expected $expect_valid valid in return for $validator-test with \"$value\"");
    is(scalar keys %$invalid, 1 - $expect_valid, "Expected ". (1-$expect_valid)." invalid in return for $validator-test with \"$value\"");
  }
}

{
  my $mock = new Test::MockModule('CGI::Push');
  my $cgi_value = "";
  $mock->mock('param', sub {
    my $key = shift;
    return $cgi_value;
  });
  my $cgi = CGI::Push->new;

  foreach my $value(sort keys %EXPECTATIONS) {
    $cgi_value = $value;
    foreach my $validator(sort keys %{$EXPECTATIONS{$value}}) {
      my $expect_valid = $EXPECTATIONS{$value}->{$validator};
      my ($valid, $invalid) = LML::Validation::validate_cgi($cgi, $SPECS{$validator});
      #print Dumper({$validator => {VALID => $valid, INVALID => $invalid}});
      is(scalar keys %$valid, $expect_valid, "Expected $expect_valid valid in return for $validator-test with \"$value\"");
      is(scalar keys %$invalid, 1 - $expect_valid, "Expected ". (1-$expect_valid)." invalid in return for $validator-test with \"$value\"");
    }
  }
}


ok($_ =~ $LML::Validation::VALIDATE_HOSTNAME, "Recognize \"$_\" as hostname")
  for qw/localhost foo foo-bar foo-bar-baz/;
ok($_ !~ $LML::Validation::VALIDATE_HOSTNAME, "Do not recognize \"$_\" as hostname")
  for qw/local.host foo.bar.baz/;


ok($_ =~ $LML::Validation::VALIDATE_FQDN, "Recognize \"$_\" as fully qualified domain name")
  for qw/localhost my-domain.tld sub.my-domain.tld/;
ok($_ !~ $LML::Validation::VALIDATE_FQDN, "Do not recognize \"$_\" as fully qualified domain name")
  for qw/bad_name not@domain/;


ok($_ =~ $LML::Validation::VALIDATE_USERNAME, "Recognize \"$_\" as username")
  for qw/alice bob mr-33foo bar_baz _zoing/;
ok($_ !~ $LML::Validation::VALIDATE_USERNAME, "Do not recognize \"$_\" as username")
  for qw/-foo invalid+name also*bad/, "bla bla";


ok($LML::Validation::VALIDATE_ONE_LINE->($_), "Recognize \"$_\" as one line")
  for ("foo", "foo bar", "foo bar-baz");
ok(!$LML::Validation::VALIDATE_ONE_LINE->($_), "Do not recognize \"$_\" as one line")
  for ("foo\n", "foo\nbar", "foo\r\nbar\r\nbaz");


ok($LML::Validation::VALIDATE_NO_PARENT_LINKS->($_), "Recognize \"$_\" as string without parent links")
  for qw{/valid/path /l/e/g/al /ok/./also};
ok(!$LML::Validation::VALIDATE_NO_PARENT_LINKS->($_), "Do not recognize \"$_\" as string without parent links")
  for qw{/../ bad/../path /very/long/path/with/../../../bad/parent/links};


ok($LML::Validation::VALIDATE_ABS_PATH->($_), "Recognize \"$_\" as valid absolute path")
  for qw{/valid/path /l/e/g/al /ok/./also};
ok(!$LML::Validation::VALIDATE_ABS_PATH->($_), "Do not recognize \"$_\" as valid absolute path")
  for qw{/../ relative/path /very/long/path/with/../../../bad/parent/links};


ok($_ =~ $LML::Validation::VALIDATE_INTEGER, "Recognize \"$_\" as integer")
  for qw/1 123 12345689/;
ok($_ !~ $LML::Validation::VALIDATE_INTEGER, "Do not recognize \"$_\" as integer")
  for qw/foo 123.4 1fe3/;


ok($_ =~ $LML::Validation::VALIDATE_NUMBER, "Recognize \"$_\" as number")
  for qw/1 123 12345689 1.1 123.345 123456789.23456879/;
ok($_ !~ $LML::Validation::VALIDATE_NUMBER, "Do not recognize \"$_\" as number")
  for qw/foo 1fe3 123,5123/;


ok($_ =~ $LML::Validation::VALIDATE_IPV4, "Recognize \"$_\" as IPv4")
  for qw/127.0.0.1 192.168.123.234 8.8.8.8 10.0.0.0/;
ok($_ !~ $LML::Validation::VALIDATE_IPV4, "Do not recognize \"$_\" as IPv4")
  for qw{123 123.123 123.123.123 123.123.123.123/16};


ok($_ =~ $LML::Validation::VALIDATE_CIDR, "Recognize \"$_\" as CIDR")
  for qw{127.0.0.1/32 192.168.0.0/16 8.0.0.0/8 10.0.0.0/12};
ok($_ !~ $LML::Validation::VALIDATE_CIDR, "Do not recognize \"$_\" as CIDR")
  for qw{123 123.123 123.123.123 123.123.123.123};


ok($_ =~ $LML::Validation::VALIDATE_UUID, "Recognize \"$_\" as UUID")
  for qw{123e4567-e89b-12d3-a456-426655440000 00000000-0000-0000-0000-000000000000};
ok($_ !~ $LML::Validation::VALIDATE_UUID, "Do not recognize \"$_\" as UUID")
  for qw{
    123e4567-e89b-12d3-a456-42665544000 123e4567-e89b-12d3-a456-4266554400001
    123e4567-e89b-12d3-a45-426655440000 123e4567-e89b-12d3-a45aa-426655440000
    123e4567-e89b-12d3a-a45a-426655440000 123e4567-e89b-12d-a45a-426655440000
    123e4567-e89-12d3-a456-426655440000 123e4567-e89ab-12d3-a456-426655440000
    123e456-e89b-12d3-a456-426655440000 123e4567a-e89b-12d3-a456-426655440000
  };


ok($_ =~ $LML::Validation::VALIDATE_GER_DATE, "Recognize \"$_\" as German date")
  for qw{31.12.2017 1.5.1999 1.1.2000 03.08.2015};
ok($_ !~ $LML::Validation::VALIDATE_GER_DATE, "Do not recognize \"$_\" as German date")
  for qw{2015-03-10 5.2000 99.10.2000 10.20.2000};

done_testing();
