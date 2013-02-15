package LML::VMpolicy;

use strict;
use Exporter;

use Carp;
use LML::VMware;
use LML::VM;
use LML::Common;
use LML::Config;

sub new {
    my ( $class, $config, $VM ) = @_;
    croak("1st parameter must be LML::Common::Config") unless ( ref($config) eq "LML::Config" );
    croak("2nd parameter must be LML::VMware::VM")     unless ( ref($VM)     eq "LML::VM" );
    my $self = {
                 Config => $config,
                 VM     => $VM,
    };
    bless( $self, $class );
    return $self;
}

sub validate_vm_name {

    # check VM name to contain only allowed characters
    my $self    = shift;
    my $vm_name = $self->{VM}->name;
    if ( $vm_name =~ m/^[a-z0-9_-]+$/ ) {
        return;
    }
    return "VM name may only contain a-z0-9_- characters";
}

sub validate_hostrules_pattern {

    # check VM name against pattern of allowed names
    my $self = shift;

    # check VM name against pattern of allowed names
    my $vm_name = $self->{VM}->name;
    my $hostrulespattern = $self->{Config}->get( "hostrules", "pattern" );
    return unless ($hostrulespattern);    # skip if not configured
    if ( $vm_name =~ $hostrulespattern ) {
        return;
    }
    return "VM name does not match '$hostrulespattern' pattern";
}

sub validate_dns_zones {

    # check VM name against other DNS zones to prevent creating duplicate entries
    my $self          = shift;
    my $vm_name       = $self->{VM}->name;
    my @dnscheckzones = @{ $self->{Config}->get( "hostrules", "dnscheckzones" ) };
    my @error;
    if ( scalar(@dnscheckzones) ) {
        for my $z (@dnscheckzones) {

            #Debug("DNS Lookup ".$vm_name . ".$z." );
            if ( scalar( gethostbyname( $vm_name . ".$z." ) ) ) {
                push( @error, "Name conflict with '$vm_name.$z.'" );
            }
        }
    }
    if (@error) {
        return @error;
    } else {
        return;
    }
}
1;
