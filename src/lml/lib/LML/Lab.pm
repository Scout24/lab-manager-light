############## OO Interface to LAB data #############
#
# OO style management of LAB

package LML::Lab;

use strict;
use warnings;

use LML::VM;
use LML::Common;
use Carp;

# new object, takes uuid
sub new {
    my ( $class, $self ) = @_;
    if ( ref($self) ne "HASH" ) {
        $self = ReadLabFile;
    }
    bless( $self, $class );
    return $self;
}

sub get_host {
    my ( $self, $uuid ) = @_;
    croak( "Must give VM uuid as first parameter in " . ( caller(0) )[3] ) unless ($uuid);
    if ( exists $self->{HOSTS}{$uuid} ) {
        return $self->{HOSTS}{$uuid};
    } else {
        return;
    }
}

sub update_host {
    my ( $self, $VM ) = @_;
    croak( "Must give LML:VM object as first parameter in " . ( caller(0) )[3] ) unless ( ref($VM) eq "LML::VM" );
    my $uuid = $VM->uuid;
    my $name = $VM->name;
    my @vm_lab_macs = $VM->get_filtered_macs;
    Debug("update LAB for '$name' with '".join(", ",@vm_lab_macs)."'");
    # add lastseen info to host
    $self->{HOSTS}->{$uuid}->{LASTSEEN} = time;
    $self->{HOSTS}->{$uuid}->{LASTSEEN_DISPLAY} = POSIX::strftime( "%a %b %e %H:%M:%S %Y", localtime );

    # create HOSTS record for DHCP if it has changed (name or networking)
    # ~~ compares array since perl 5.10!!
    #
    # NOTE: This should be after all other pieces of code that compare with the old host name !!!
    if (    not( exists( $self->{HOSTS}->{$uuid}->{HOSTNAME} ) and exists( $self->{HOSTS}->{$uuid}->{MACS} ) )
         or not $name eq $self->{HOSTS}->{$uuid}->{HOSTNAME}
         or not @vm_lab_macs ~~ @{ $self->{HOSTS}->{$uuid}->{MACS} } )
    {
        $self->{HOSTS}->{$uuid}->{HOSTNAME} = $name;
        $self->{HOSTS}->{$uuid}->{MACS}     = \@vm_lab_macs;
        return 1;
        Debug("host data changed in LAB");
    } else {
        return; # return nothing to indicate that nothing changed
    }
}

1;
