############## OO Interface #############
#
# create a VM object which encapsulates a single VM

package LML::VM;

use strict;
use warnings;

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
    } else {

        unless ($uuid) {
            carp("Give the VM uuid as arg to the constructor");
            return undef;
        }
        my %VM_DATA = get_vm_data($uuid);
        if ( !%VM_DATA ) {
            Debug("Could not load any data for uuid '$uuid'");
            return undef;
        }
        $self = \%VM_DATA;
    }
    $self->{filter_networks} = [];
    bless( $self, $class );
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

sub get_macs {
    my $self = shift;
    return undef unless ( exists $self->{"MAC"} and ref( $self->{"MAC"} ) eq "HASH" );
    return keys( %{ $self->{"MAC"} } );
}

sub set_networks_filter {
    my ( $self, @filter_networks ) = @_;
    croak("Give a list of networks to set filter") unless (@filter_networks);
    Debug("setting networks filter '".join(",",@filter_networks)."'");
    $self->{filter_networks} = \@filter_networks;
}

sub get_filtered_macs {
    my $self = shift;
    my @filter_networks = @{$self->{filter_networks}};
    return $self->get_macs unless ( scalar( @filter_networks ) ); #return filtered macs, no filter set means return all
    my @matching_macs;
    for my $mac ( $self->get_macs ) {
          if ( grep { $_ eq $self->{"MAC"}->{$mac} } @filter_networks ) {
              push( @matching_macs, $mac );
          }
    }
    return @matching_macs;
}

sub forcenetboot {
      my $self = shift;
      return exists $self->{EXTRAOPTIONS}{'bios.bootDeviceClasses'} and "$self->{EXTRAOPTIONS}{'bios.bootDeviceClasses'}" eq "allow:net";
}

sub activate_forcenetboot {
      my $self = shift;
      setVmExtraOptsU( $self->uuid, "bios.bootDeviceClasses", "allow:net" );
}
1;
