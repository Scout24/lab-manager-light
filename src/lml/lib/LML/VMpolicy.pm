package LML::VMpolicy;

use strict;
use warnings;

use Carp;
use Socket;
use LML::VMware;
use LML::VM;
use LML::Common;
use LML::Config;

sub new {
    my ( $class, $config, $VM ) = @_;
    croak( "1st parameterto " . ( caller(0) )[3] . " must be a LML::Common::Config object" ) unless ( ref($config) eq "LML::Config" );
    croak( "2nd parameterto " . ( caller(0) )[3] . " must be a LML::VMware::VM object" )     unless ( ref($VM)     eq "LML::VM" );
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
    Debug("validating name '$vm_name' against ^[a-z0-9_-]+\$");
    if ( $vm_name =~ m/^[a-z0-9_-]+$/ ) {
        return;
    }
    return "VM name may only contain a-z0-9_- characters";
}

sub validate_hostrules_pattern {

    # check VM name against pattern of allowed names
    my $self             = shift;
    my $vm_name          = $self->{VM}->name;
    my $hostrulespattern = $self->{Config}->get( "hostrules", "pattern" );
    return unless ($hostrulespattern);    # skip if not configured
    Debug("validating name '$vm_name' against $hostrulespattern");
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

            Debug( "validating name in other DNS domain: " . $vm_name . ".$z." );
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

sub validate_contact_user {

    # check VM contact user against local user database
    my $self = shift;
    my @error;
    my $contactuserid_field  = $self->{Config}->get( "vsphere", "contactuserid_field" );
    my $contactuserid_minuid = $self->{Config}->get( "vsphere", "contactuserid_minuid" );
    if ($contactuserid_field) {
        if ( exists $self->{VM}{CUSTOMFIELDS}{$contactuserid_field} ) {
            my $contactuserid = $self->{VM}{CUSTOMFIELDS}{$contactuserid_field};

            Debug("validating user $contactuserid > $contactuserid_minuid");

            # Ask OS about user
            my @pwnaminfo = getpwnam($contactuserid);
            if ( @pwnaminfo and scalar(@pwnaminfo) ) {

                # user exists, make sure that user is allowed
                if ($contactuserid_minuid) {
                    if ( $pwnaminfo[2] < $contactuserid_minuid ) {
                        push( @error, "$contactuserid_field '" . $contactuserid . "' is not allowed" );
                    }
                }
            } else {
                push( @error, "$contactuserid_field '" . $contactuserid . "' does not exist" );
            }
        } else {
            push( @error, "Must set $contactuserid_field to valid username" );
        }
    }    # else test not configured
    if (@error) {
        return @error;
    } else {
        return;
    }
}

sub validate_expiry {

    # check that the VM did not expire
    my $self = shift;
    my @error;
    my $expires_field = $self->{Config}->get( "vsphere", "expires_field" );
    if ( exists $self->{VM}{CUSTOMFIELDS}{$expires_field} ) {
        my $vmdate   = $self->{VM}{CUSTOMFIELDS}{$expires_field};
        my $expires  = "THERE WAS AN ERROR";
        my $european = $self->{Config}->get( "vsphere", "expires_european" ) ? 1 : 0;
        eval { $expires = DateTime::Format::Flexible->parse_datetime( $vmdate, european => $european ) };
        if ($@) {
            push( @error, "Cannot parse $expires_field date '" . $vmdate . "'" );
        } elsif ( DateTime->compare( DateTime->now(), $expires ) > 0 ) {
            push( @error, "VM expired on " . $expires );
        }
        Debug("validating expiry '$vmdate', parsed as '$expires'");

        # implicit logic: If we got here without errors then the date is parsable and in the future
    } else {
        push( @error, "Must set $expires_field to valid date or date/time" );
    }
    if (@error) {
        return @error;
    } else {
        return;
    }
}

# TODO: The following test fails to notice name conflicts against offline machines that do not have a DNS records at the moment
# you might want to increase your lease time to counter this effect or add some code to compare the new name against
# the list of known hostnames in $LAB
sub validate_vm_dns_name {

    # check if the VM name exists already in our managed DNS domain.
    # the only situation where this is OK is if the VM existed already before and the VM name did not change
    my ( $self, $LAB ) = @_;

    # validate arg
    croak( "Parameter to " . ( caller(0) )[3] . " must be LAB hash" ) unless ( ref($LAB) eq "HASH" and exists $LAB->{HOSTS} );
    my $vm_name      = $self->{VM}->name;
    my $vm_uuid      = $self->{VM}->uuid;
    my $appenddomain = $self->{Config}->get( "dhcp", "appenddomain" );
    return unless ($appenddomain);    # nothing to do if no DNS domain to append given
    my $vm_fqdn = $vm_name . ".$appenddomain.";
    my ( $dns_fqdn, $aliases, $addrtype, $length, @addrs ) = gethostbyname($vm_fqdn);
    Debug( "validating name '$vm_name' in managed DNS domain: $appenddomain: " . join( ", ", map { inet_ntoa($_) } @addrs ) );

    if ( exists( $LAB->{HOSTS}->{$vm_uuid}->{HOSTNAME} ) ) {
        # we have old data
        if ( $vm_name eq $LAB->{HOSTS}->{$vm_uuid}->{HOSTNAME} ) {
            # old name equals new name
            return;
        } elsif ($dns_fqdn) {
            # new VM name exists in DNS
            return "Renamed VM '$vm_fqdn' name exists already in '$appenddomain'";
        }    # else new VM name does not exist in DNS -> all OK
    } else {
        # we don't have old data, must be new VM
        if ($dns_fqdn) {
            # new VM name conflicts with existing systems in managed domain
            return "New VM name exists already in '$appenddomain'";
        }
    }
    return;
}
1;
