############## OO Interface #############
#
# create a VM object which encapsulates a single VM

package LML::VM;

use strict;
use warnings;

use LML::Config;
use LML::VMware;
use LML::Common;
use Carp;

# new object, takes uuid
sub new {
    my $class = shift;
    my $self;
    my $uuid = shift;
    if ( ref($uuid) eq "HASH" ) {
        # hashref given, turn it into a VM object.
        # if some of the data structures are missing, then you are on your own!
        $self = $uuid;
        # migrate old LAB structure to new VM structure
        if ( !exists $self->{NAME} and exists $self->{HOSTNAME} ) {
            $self->{NAME} = $self->{HOSTNAME};
        }
    } else {

        unless ($uuid) {
            carp( "Give the VM uuid as arg to the constructor in " . ( caller 0 )[3] );
            return undef;
        }
        $self = get_vm_data($uuid);
        if ( not ref($self) eq "HASH" ) {
            Debug("Could not load any data for uuid '$uuid'");
            return undef;
        }
    }
    $self->{filter_networks} = [];
    bless $self, $class;
    return $self;
}

sub uuid {
    my $self = shift;
    return undef unless ( exists $self->{"UUID"} );
    return $self->{"UUID"};
}

sub name {
    my $self = shift;
    return undef unless ( exists $self->{"NAME"} );
    return $self->{"NAME"};
}

sub vm_id {
    my $self = shift;
    return undef unless ( exists $self->{"VM_ID"} );
    return $self->{"VM_ID"};
}

sub mac {
    my $self = shift;
    return undef unless ( exists $self->{"MAC"} );
    return $self->{"MAC"};
}

sub path {
    my $self = shift;
    return undef unless ( exists $self->{"PATH"} );
    return $self->{"PATH"};
}

sub host {
    my $self = shift;
    return undef unless ( exists $self->{"HOST"} );
    return $self->{"HOST"};
}

sub customfields {
    my $self = shift;
    return undef unless ( exists $self->{"CUSTOMFIELDS"} );
    return $self->{"CUSTOMFIELDS"};
}

sub get_macs {
    my $self = shift;
    return undef unless ( exists $self->{"MAC"} and ref( $self->{"MAC"} ) eq "HASH" );
    return keys %{ $self->{"MAC"} };
}

sub set_networks_filter {
    my ( $self, @filter_networks ) = @_;
    croak( "Give a list of networks to set filter in " . ( caller 0 )[3] ) unless (@filter_networks);
    Debug( "setting networks filter '" . join( ",", @filter_networks ) . "'" );
    $self->{filter_networks} = \@filter_networks;
}

sub get_filtered_macs {
    my $self            = shift;
    my @filter_networks = @{ $self->{filter_networks} };
    return $self->get_macs unless ( scalar @filter_networks );    #return filtered macs, no filter set means return all
    my @matching_macs;
    for my $mac ( $self->get_macs ) {
        if ( grep { $self->{"MAC"}->{$mac} =~ qr(^$_$) } @filter_networks ) {
            push @matching_macs, $mac;
        }
    }
    return @matching_macs if (wantarray);
    return scalar @matching_macs;
}

sub forcenetboot {
    my $self = shift;
    return exists $self->{EXTRAOPTIONS}{'bios.bootDeviceClasses'} and $self->{EXTRAOPTIONS}{'bios.bootDeviceClasses'} eq "allow:net";
}

sub activate_forcenetboot {
    my $self = shift;
    setVmExtraOptsU( $self->uuid, "bios.bootDeviceClasses", "allow:net" );
}

sub reboot {
    my $self = shift;
    return perform_reboot( $self->uuid );
}

sub reset {
    my $self = shift;
    return perform_reset( $self->uuid );
}

sub poweroff {
    my $self = shift;
    return perform_poweroff( $self->uuid );
}

sub destroy {
    my $self = shift;
    # Currently we only use Config here in this object
    my $C = new LML::Config();

    # If the destroy command is successful, then go ahead with the cleanup tasks
    if ( perform_destroy( $self->uuid ) ) {
        # Cleanup the lab configuration to do not show this machine again
        my $LAB = new LML::Lab( $C->labfile );
        $LAB->remove( $self->uuid );
        $LAB->write_file( "by " . __FILE__ );

        # And additionally remove the machine from dhcp configuration
        if ( LML::DHCP::UpdateDHCP( $C, $LAB ) ) {
            Debug("DHCP update for uuid " . $self->uuid . " exited with errors");
            return 0;
        }
    }
}

    1;
