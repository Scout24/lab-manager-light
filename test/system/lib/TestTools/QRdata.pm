package TestTools::QRdata;

#TODO: cp assert methods from integration-test.pl

use strict;
use warnings;

use constant MAX_QR_CODE_AGE_SEC => 180;    # 3 minutes

sub new {
    my ( $class, $vm_created, $vm_create_options ) = @_;

    my $self = {
                 vm_created           => $vm_created,
                 vm_create_options => $vm_create_options
    };

    bless $self, $class;

    return $self;
}

# asserts a single field in the vm specification
sub assert {
    my ($self)   = @_;
    my $spec     = shift;
    my $field    = shift;
    my $expected = shift;
    my $actual   = $spec->{"$field"};
    $self->__fail_team_city_build("expected $field: $expected, actual: $actual") if ( "$actual" ne "$expected" );
}

# asserts that the QR code is not too old
sub assert_qr_code_age {
    my ($self) = @_;
    my $time = $self->{vm_created}->{"UPDATED"};
    $self->_fail_team_city_build( "QR code " . ( time - $time ) . " seconds old, more than allowed " . MAX_QR_CODE_AGE_SEC, "1" )
      if ( time - $time > MAX_QR_CODE_AGE_SEC );
}

#####################################################################
#####################################################################
# PRIVATE FUNCTIONS
#####################################################################
#####################################################################

# logs TeamCity build status message with FAILURE status
sub _fail_team_city_build {
    my $reason = shift;
    print "##teamcity[buildStatus status='FAILURE' text='$reason']" . $/;
    exit 1;
}
1;
