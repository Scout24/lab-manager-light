package TestTools::QRdata;

use strict;
use warnings;
use JSON;

use constant MAX_QR_CODE_AGE_SEC => 180;    # 3 minutes

sub new {
    my ( $class, $uuid_from_create_script, $vm_created, $vm_create_options ) = @_;

    my $vm_created_json = decode_json($vm_created); # TODO: handle parse errors
    
    my $self = {
                 uuid_from_create_script => $uuid_from_create_script,
                 vm_created              => $vm_created,
                 vm_created_json          => $vm_created_json,
                 vm_create_options       => $vm_create_options
    };

    bless $self, $class;

    return $self;
}

# asserts that the QR code is not too old
sub assert_qr_code_age {
    print "##teamcity[progressMessage 'Validating QR-code age']\n";
    my ($self) = @_;
    my $time = $self->{vm_created_json}->{"UPDATED"};
    my $age = -1;

    if (defined($time)){
        $age = time - $time;
        $self->_fail_team_city_build( "QR code " . ( $age ) . " seconds old, more than allowed " . MAX_QR_CODE_AGE_SEC, "1" )
            if ( $age > MAX_QR_CODE_AGE_SEC );
    } else {
        $self->_fail_team_city_build( "QR code is an error code and not a expected qr code for a successfully created vm.")
    }
}

# asserts the vm path
sub assert_vm_path {
    print "##teamcity[progressMessage 'Validating vm path']\n";
    my ($self)  = @_;
    my $path    = $self->{vm_created_json}->{"PATH"};
    my $folder  = $self->{vm_create_options}->{folder};

    $self->_fail_team_city_build("expected path: $folder, actual $path") if ( $path !~ /$folder/ );
}

# assert the lml host
sub assert_lml_host {
    print "##teamcity[progressMessage 'Validating vm lml host']\n";
    my ($self)         = @_;
    my $lmlhost        = $self->{vm_created_json}->{"LMLHOST"};
    my $lmlhostpattern = $self->{vm_create_options}->{lmlhostpattern};
    $self->_fail_team_city_build("expected LML host pattern $lmlhostpattern does not match $lmlhost") if ( $lmlhost !~ /$lmlhostpattern/ );
}

# assert the uuid
sub assert_uuid {
    print "##teamcity[progressMessage 'Validating vm uuid']\n";
    my ($self)        = @_;
    my $uuid          = $self->{vm_created_json}->{"UUID"};
    my $expected_uuid = $self->{uuid_from_create_script};
    $self->_fail_team_city_build("actual qr-code-uuid $uuid does not match uuid $expected_uuid from create script") unless ( $expected_uuid eq $uuid );
}

# assert the host
sub assert_host {
    my ($self)        = @_;
    # verify esx host only, if it was explicit given in the create options (no auto placement)
    unless (defined $self->{vm_create_options}->{esx_host}){
        return;
    }
    print "##teamcity[progressMessage 'Validating vm host']\n";
    my $host          = $self->{vm_created_json}->{"HOST"};
    my $expected_host = $self->{vm_create_options}->{esx_host};
    $self->_fail_team_city_build("actual host $host does not match host $expected_host from create options") unless ( $expected_host eq $host );
}

# assert the hostname
sub assert_hostname {
    print "##teamcity[progressMessage 'Validating vm hostname']\n";
    my ($self)            = @_;
    my $hostname          = $self->{vm_created_json}->{"HOSTNAME"};
    my $expected_hostname = $self->{vm_create_options}->{vm_host};
    $self->_fail_team_city_build("actual host $hostname does not match hostname $expected_hostname from create options") unless ( $expected_hostname eq $hostname );
}

# assert the contact user id
sub assert_contact_user_id {
    print "##teamcity[progressMessage 'Validating vm contact user id']\n";
    my ($self)           = @_;
    my $contact          = $self->{vm_created_json}->{"CUSTOMFIELDS"}->{"Contact User ID"};
    my $expected_contact = $self->{vm_create_options}->{username};
    $self->_fail_team_city_build("actual contact id $contact does not match contact id $expected_contact from create options") unless ( $expected_contact eq $contact );
}

# assert the expiration date
sub assert_expiration_date {
    print "##teamcity[progressMessage 'Validating vm expiration date']\n";
    my ($self)                   = @_;
    my $expiration_date          = $self->{vm_created_json}->{"CUSTOMFIELDS"}->{"Expires"};
    my $expected_expiration_date = $self->{vm_create_options}->{expiration_date};
    $self->_fail_team_city_build("actual expiration date $expiration_date does not match expiration date $expected_expiration_date from create options") unless ( $expected_expiration_date eq $expiration_date );
}

# assert the expiration date
sub assert_regex {
    my ($self, $regex) = @_;
    print "##teamcity[progressMessage 'Validating qr text for matching pattern \"$regex\"']\n";

    my $text = $self->{vm_created};
    $self->_fail_team_city_build("the following text does not match the pattern $regex: \"$text\"") unless ($text =~ qr(^$regex$)ms );
}

#####################################################################
#####################################################################
# PRIVATE FUNCTIONS
#####################################################################
#####################################################################

# asserts a single field in the vm specification
sub _assert {
    my ($self)   = @_;
    my $spec     = shift;
    my $field    = shift;
    my $expected = shift;
    my $actual   = $spec->{"$field"};
    $self->_fail_team_city_build("expected $field: $expected, actual: $actual") if ( "$actual" ne "$expected" );
}

# logs TeamCity build status message with FAILURE status
sub _fail_team_city_build {
    my ( $self, $reason ) = @_;
    print "##teamcity[buildStatus status='FAILURE' text='$reason']\n";
    die "An error occured - skipping tests.";
}

1;
