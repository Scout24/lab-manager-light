package LML::VMplacement::Filters::ByDiskSpace;

use strict;
use warnings;
use Carp;
use Data::Dumper;

sub new {
    my ( $class, $lab ) = @_;

    croak( "1st argument must be an instance of LML::Lab called at " .    ( caller 0 )[3] ) unless ( ref($lab)    eq "LML::Lab" );

    my $self = {
        lab => $lab,
    };

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host, $vm_res, $error_ref ) = @_;
    if (! (defined( $host->{datastores}[0] ))) {
        croak( "missing data in host\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    $error_ref = [] unless (defined $error_ref and ref($error_ref) eq "ARRAY");

    my $datastore_id = $host->{datastores}[0];
    my $datastore = $self->{lab}->get_datastore($datastore_id);

    # print STDERR "DEBUG: ".Data::Dumper->Dump([$vm_res, $datastore_id, $datastore], ["vm_res", "datastore_id", "datastore"])."\n";

    if (! $datastore) {
        croak( "missing datastore (". $datastore_id .") in lab\n" . Data::Dumper->Dump( [$host], ["host"] ) . "\ngiven in " . ( caller 0 )[3] )
    }

    if (! (defined( $datastore->{freespace} ))) {
        croak( "missing freespace attribute in datastore\n" . Data::Dumper->Dump( [$datastore], ["datastore"] ) . "\ngiven in " . ( caller 0 )[3] )
    }

    my $vm_total_disk_size = 0;
    foreach my $disk (@{$vm_res->{disks}}) {
        $vm_total_disk_size+=$disk->{size} * 1024 ; # disk of new vm is given in KB, convert to Bytes
        # See lib/LML/VMcreate/VMproperties.pm for how the disk size is filled in :-(
    }
    
    if (! (defined( $vm_res->{ram}) ) ) {
        croak( "missing ram attribute in vm_res\n" . Data::Dumper->Dump( [$vm_res], ["vm_res"] ) . "\ngiven in " . ( caller 0 )[3] )
    }
    my $vm_ram_size = $vm_res->{ram} * 1024 * 1024; # RAM is given in MB, convert to Bytes
    my $vm_overhead_size = 200 * 1024 * 1024; # Add 200 MB extra space for overhead
    my $total_required_disk_space = $vm_total_disk_size + $vm_ram_size + $vm_overhead_size; 
    if ( $total_required_disk_space < $datastore->{freespace}) { 
        return 1;
    }
    print STDERR "DEBUG: Removed $host->{name} because $total_required_disk_space = $vm_total_disk_size + $vm_ram_size + $vm_overhead_size B and does not fit in $datastore->{freespace} Bytes free space\n" ;
    push @$error_ref, "Host $host->{name} does not have $total_required_disk_space byte free diskspace";
    return 0;
}

sub filter_hosts {
    my ($self, $error_ref, $vm_res, @hosts) = @_;
    return grep { $self->host_can_vm($_,$vm_res,$error_ref) } @hosts; 
}

sub get_name {
    return 'ByDiskSpace';
}
1;
