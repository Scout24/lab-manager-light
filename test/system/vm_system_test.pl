#!/usr/bin/perl -w

# required RPM dependencies on RHEL/compatible:
# zbar
# gocr
# perl-libwww-perl
# perl-JSON
# perl-DateTime
# per-Config-IniFiles

# Defaults
use strict;
use warnings;

use FindBin;
use lib "$FindBin::RealBin/lib";

# Our test modules
use TestTools::VMmanager;
use TestTools::VmCreateOptions;
use TestTools::TestDataProvider;

use TeamCity::Messages;

# For debugging
use Data::Dumper;

sub assert_qr {
    my ( $qrdata, $test_definition ) = @_;
    foreach my $pattern ( @{ $test_definition->{expect} } ) {
        $qrdata->assert_regex($pattern);
    }
}

sub assert_qrdata {
    my ($qrdata) = @_;

    $qrdata->assert_qr_code_age();
    $qrdata->assert_vm_path();
    $qrdata->assert_lml_host();
    $qrdata->assert_uuid();
    $qrdata->assert_host();
    $qrdata->assert_hostname();
    $qrdata->assert_contact_user_id();
    $qrdata->assert_expiration_date();
}

sub excute_test_case {
    my ($test_definition) = @_;
    my $test_result       = 0;
    my $vm_create_options = new TestTools::VmCreateOptions($test_definition);

    my $vm_manager = new TestTools::VMmanager($vm_create_options);
    my $vm_created = $vm_manager->create_vm();
    eval {
        if ( "qrdata" eq $test_definition->{result} )
        {
            my $qrdata = $vm_created->load_qrdata();
            assert_qrdata($qrdata);
            assert_qr( $qrdata, $test_definition );
        }
        elsif ( "qr" eq $test_definition->{result} ) {
            assert_qr( $vm_created->load_qrdata(), $test_definition );
        }
        elsif ( "ocr" eq $test_definition->{result} ) {
            $vm_created->match_ocr($test_definition);
        }
        else {
            teamcity_build_failure("Integration Test '$test_definition->{label}' uses unkown result type '$test_definition->{result}'");
            die;    # should find better way without this eval.
        }
    };
    if ($@) {
        teamcity_build_failure("Integration Test '$test_definition->{label}' FAILED");
    }
    else {
        teamcity_build_success("Integration Test '$test_definition->{label}' OK");
        $test_result = 1;
    }
    $vm_manager->delete_vm();
    return $test_result;
}

my @test_spec       = TestTools::TestDataProvider->parseTestData();
my $counter         = 1;
my $good_tests      = 0;
my $number_of_tests = scalar(@test_spec);

if ( !$number_of_tests ) {
    teamcity_build_failure('No System Tests configured!');
}
else {
    foreach my $test_case (@test_spec) {
        teamcity_build_progress("Running test ($counter/$number_of_tests) '$test_case->{label}'");
        if ( excute_test_case($test_case) ) {
            $good_tests++;
        }
        $counter++;
    }

    teamcity_build_status( $number_of_tests == $good_tests,
                           sprintf 'Tests passed:%d failed:%d',
                           $good_tests, $number_of_tests - $good_tests );
}

exit ($number_of_tests == $good_tests ? 0 : 1);
