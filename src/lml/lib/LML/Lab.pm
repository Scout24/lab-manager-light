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
    if ( ref($arg) eq "HASH") {
        # arg is hashref
        $self = $arg;
    } elsif (ref($arg) eq "") {
        # arg is not a reference but a scalar, should be file name of lab file
        my $LAB->{HOSTS} = {};
        if ( -r $arg ) {
            local $/ = undef;
            open( LAB_CONF, "<", $arg ) || croak "Could not open $arg for reading.\n";
            flock( LAB_CONF, 1 ) || croak "Could not lock $arg.\n";
            binmode LAB_CONF;
            eval <LAB_CONF> || croak "Could not parse $arg:\n$@\n";
            close(LAB_CONF);
        }
        croak '$LAB is not a hashref or empty, your $arg file must be broken.\n' unless ( ref($LAB) eq "HASH" and scalar( %{$LAB} ) );
        $self = $LAB;
        $self->{filename}=$arg; # keep filename if we read the data from a file
    } else {
        croak "Parameter to ".(caller(0))[3]." should be hashref with LAB data or filename of LAB file and not ".ref($arg)."\n";
    }
    bless( $self, $class );
    return $self;
}

sub set_filename {
    my ($self,$filename) = @_;
    croak("Must give filename in ".(caller(0))[3]."\n") unless ($filename);
    $self->{filename}=$filename;
}

sub filename {
    my $self = shift;
    return $self->{filename} if (exists $self->{filename});
    return undef;
}

sub get_host {
    my ( $self, $uuid ) = @_;
    croak( "Must give VM uuid as first parameter in " . ( caller(0) )[3]."\n" ) unless ($uuid);
    if ( exists $self->{HOSTS}{$uuid} ) {
        return $self->{HOSTS}{$uuid};
    } else {
        return;
    }
}

# update data about single host from given VM object
sub update_host {
    my ( $self, $VM ) = @_;
    croak( "Must give LML:VM object as first parameter in " . ( caller(0) )[3]."\n" ) unless ( ref($VM) eq "LML::VM" );
    my $uuid        = $VM->uuid;
    my $name        = $VM->name;
    my @vm_lab_macs = $VM->get_filtered_macs;
    Debug( "update LAB for '$name' with '" . join( ", ", @vm_lab_macs ) . "'" );
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
        return;    # return nothing to indicate that nothing changed
    }
}

sub write_file {
    my ($self,@comments) = @_;
    my $filename = $self->filename;
    croak("No filename associated with LML::Lab object\n") unless ($filename);
    open( LAB_CONF, ">", $filename ) || croak "Could not open '$filename' for writing: $!\n";
    flock( LAB_CONF, 2 ) || croak "Could not lock '$filename': $!\n";
    print LAB_CONF "# " . POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime() ) . " ".join(", ",@comments)."\n";
    my $LAB = {};
    $LAB->{HOSTS}= $self->{HOSTS}; # copy just hosts part (by reference)
    print LAB_CONF Data::Dumper->Dump( [$LAB], [qw(LAB)] ) or croak "Could not write to '$filename': $!\n";
    my $bytes_written = tell LAB_CONF;
    close(LAB_CONF);
    return $bytes_written;
}   


1;
