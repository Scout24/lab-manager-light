############## OO Interface to LAB data #############
#
# OO style management of LAB

package LML::Lab;

use strict;
use warnings;

use LML::VM;
use LML::Common;
use Carp;
use Data::Dumper;

# new object, takes LAB hash or filename to read from.
sub new {
    my ( $class, $arg ) = @_;
    my $self;
    my $filename;
    if ( ref($arg) eq "HASH" ) {
        # arg is hashref
        $self = $arg;
    } elsif ( ref($arg) eq "" ) {
        # arg is not a reference but a scalar, should be file name of lab file
        my $LAB = {
                    "HOSTS"    => {},
                    "ESXHOSTS" => {} };
        if ( -r $arg ) {
            local $/ = undef;
            open( LAB_CONF, "<", $arg ) || croak "Could not open $arg for reading.\n";
            flock( LAB_CONF, 1 ) || croak "Could not lock $arg.\n";
            binmode LAB_CONF;
            eval <LAB_CONF> || croak "Could not parse $arg:\n$@\n";
            close(LAB_CONF);
        }
        if ( ref($LAB) eq "HASH" and scalar( %{$LAB} ) ) {
            # make sure that LAB is a non-empty hashref
            $self = $LAB;
            $self->{filename} = $arg;    # keep filename if we read the data from a file
        } else {
            croak '$LAB is not a hashref or empty, your $arg file must be broken.\n';
        }

    } else {
        croak "Parameter to " . ( caller(0) )[3] . " should be hashref with LAB data or filename of LAB file and not " . ref($arg) . "\n";
    }
    $self->{vms_to_update} = [];    # list of uuids for whom the DHCP data changed
    bless( $self, $class );
    return $self;
}

sub set_filename {
    my ( $self, $filename ) = @_;
    croak( "Must give filename in " . ( caller(0) )[3] . "\n" ) unless ($filename);
    $self->{filename} = $filename;
}

sub filename {
    my $self = shift;
    return $self->{filename} if ( exists $self->{filename} );
    return undef;
}

sub list_hosts {
    my ($self) = @_;
    return sort( keys( %{ $self->{HOSTS} } ) );
}

sub get_vm {
    my ( $self, $uuid ) = @_;
    croak( "Must give VM uuid as first parameter in " . ( caller(0) )[3] . "\n" ) unless ($uuid);
    if ( exists $self->{HOSTS}{$uuid} ) {
        return new LML::VM($self->{HOSTS}{$uuid});
    } else {
        return;
    }
}

sub remove {
    my ( $self, $uuid ) = @_;
    croak( "Must give UUID to remove " . ( caller(0) )[3] ) unless ($uuid);
    if ( delete $self->{HOSTS}{$uuid} ) {
        Debug("Removing $uuid from LAB");
    }

    return 1;
}

# update the list of ESX hosts
sub update_hosts {
    my ( $self, $hosts ) = @_;
    $self->{ESXHOSTS} = $hosts;
}

# update data about single host from given VM object
sub update_vm {
    my ( $self, $VM ) = @_;
    croak( "Must give LML:VM object as first parameter in " . ( caller(0) )[3] . "\n" )
      unless ( ref($VM) eq "LML::VM" );
    my $uuid        = $VM->uuid;
    my $name        = $VM->name;
    my $vm_id       = $VM->vm_id;
    my @vm_lab_macs = $VM->get_filtered_macs;

    Debug( "Updating LAB for '$name' with '" . join( ", ", @vm_lab_macs ) . "'" );

    # add timestamp so that we know when the host was last time updated with fresh data

    # create HOSTS record for DHCP if it has changed (name or networking)
    # ~~ compares array since perl 5.10!!
    #
    # NOTE: Hostname and MACs are relevant for DHCP servers
    my $update_dhcp = (
                        not(     exists( $self->{HOSTS}->{$uuid}->{HOSTNAME} )
                             and exists( $self->{HOSTS}->{$uuid}->{MACS} ) )
                          or not $name eq $self->{HOSTS}->{$uuid}->{HOSTNAME}
                          or not @vm_lab_macs ~~ @{ $self->{HOSTS}->{$uuid}->{MACS} } ) ? 1 : 0;    # set to 0 or 1
    if ($update_dhcp) {
        push( @{ $self->{vms_to_update} }, $uuid );
    }
    $self->{HOSTS}->{$uuid} = {
                                UPDATED         => time,
                                UPDATED_DISPLAY => POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime ),
                                UUID            => $uuid,
                                HOSTNAME        => $name,
                                NAME            => $name,
                                MACS            => \@vm_lab_macs,
                                VM_ID           => $vm_id,
                                MAC             => $VM->mac,
                                CUSTOMFIELDS    => $VM->customfields,
                                PATH            => $VM->path,
                                HOST            => $VM->host,
    };

    return $update_dhcp;
}

sub vms_to_update {
    my ($self) = @_;
    return wantarray ? @{ $self->{vms_to_update} } : scalar( @{ $self->{vms_to_update} } );
}

sub write_file {
    my ( $self, @comments ) = @_;
    my $filename = $self->filename;
    croak("No filename associated with LML::Lab object\n") unless ($filename);
    open( LAB_CONF, ">", $filename ) || croak "Could not open '$filename' for writing: $!\n";
    flock( LAB_CONF, 2 ) || croak "Could not lock '$filename': $!\n";
    print LAB_CONF "# " . POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime() ) . " " . join( ", ", @comments ) . "\n";
    my $LAB = {};
    # copy just hosts part (by reference)
    $LAB->{HOSTS}    = $self->{HOSTS};
    $LAB->{ESXHOSTS} = $self->{ESXHOSTS};
    print LAB_CONF Data::Dumper->Dump( [$LAB], [qw(LAB)] ) or croak "Could not write to '$filename': $!\n";
    my $bytes_written = tell LAB_CONF;
    close(LAB_CONF);
    return $bytes_written;
}

1;
