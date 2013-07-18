#!/usr/bin/perl -w

# required RPM dependencies on RHEL/compatible:
# zbar
# perl-libwww-perl
# perl-JSON
# perl-DateTime

# Defaults
use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/lib";

# Our test modules
use TestTools::VMmanager;
use TestTools::VmCreateOptions;

# For debugging
use Data::Dumper;

my $vm_manager = new TestTools::VMmanager();
my $vm_created = $vm_manager->create_vm();
my $qr_data = $vm_created->load_qrdata();

$qr_data->assert_failure_wrong_network();

$vm_manager->delete_vm();
print "##teamcity[buildStatus status='SUCCESS' text='Integration Test OK']" . $/;

END {
    $vm_manager->delete_vm();
}
