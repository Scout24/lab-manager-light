package LML::VMplacement::Filters::ByGroupReliability;

use strict;
use warnings;
use Carp;
use Data::Dumper;

sub new {
    my ( $class, $lab, $config ) = @_;

    croak( "1st argument must be an instance of LML::Lab called at " .    ( caller 0 )[3] ) unless ( ref($lab)    eq "LML::Lab" );
    croak( "2nd argument must be an instance of LML::Config called at " . ( caller 0 )[3] ) unless ( ref($config) eq "LML::Config" );
    
    my $self = {
                 lab    => $lab,
                 config => $config,
    };

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host, $vm_res ) = @_;
    
    my $group_pattern = $self->{config}->{hostrules}->{group_pattern};
    if (!defined($group_pattern)){
        return 1; # do not filter if no group pattern was defined
    }

    $vm_res->{name} =~ qr(^$group_pattern$);
    my $expected_group = $1;
    if (!defined($expected_group)){
        return 1; # do not filter if a group pattern was defined but we can not determine the group of our vm 
    }

    my $number_of_vms_with_same_group_per_host = $self->_get_number_of_vms_with_same_group_per_host( $vm_res,$group_pattern,$expected_group );
    my $minimum = $self->_get_minimum_number_of_vms_with_same_group($number_of_vms_with_same_group_per_host);
    
    # print STDERR "DEBUG: host \"$host->{id}\" owns $number_of_vms_with_same_group_per_host->{$host->{id}} vms of same group.\n";
    # print STDERR "DEBUG: But there is another host who owns only $minimum vms of same group.\n" if ($number_of_vms_with_same_group_per_host->{$host->{id}} > $minimum);
     
    return 0 if ($number_of_vms_with_same_group_per_host->{$host->{id}} > $minimum);
    return 1;
}

sub get_name {
    return 'ByGroupReliability';
}

##################################################
# private methods
##################################################

sub _get_number_of_vms_with_same_group_per_host {
    my ( $self,  $vm_res, $group_pattern,$expected_group ) = @_;

    my %number_of_vms_with_same_group_per_host = ();

    # iterate over all esx hosts        
    foreach my $host ($self->{lab}->get_hosts) {

        my $counter_same_vm_groups = 0;
        
        # TODO: is there a more perl style to express these nested foreach loops?
        # iterate over all vms on this esx host
        foreach my $vm_id ( @{ $self->{lab}->{ESXHOSTS}{ $host->{id} }->{vms} } ) {
    
            # now the bad thing: iterate over all vms (independent from host) and try to find vm with same id, because we do not know the name of the vm
            foreach my $vm ( keys $self->{lab}->{HOSTS} ) {
                # is this the vm with a matching id
                if ( $vm_id eq $self->{lab}->{HOSTS}->{$vm}->{VM_ID} ) {
                    # resolve group of matching vm
                    $self->{lab}->{HOSTS}->{$vm}->{NAME} =~ qr(^$group_pattern$);
                    # if vm group is same, increase the vm counter for this host  
                  
                    if ( !defined($expected_group) || $expected_group eq $1 ) {
                        $counter_same_vm_groups++;
                    }
                    
                    # break, because we already found our vm 
                    last;
                }

            }

        }
        $number_of_vms_with_same_group_per_host{$host->{id}} = $counter_same_vm_groups;
    }
    return \%number_of_vms_with_same_group_per_host;
}

sub _get_minimum_number_of_vms_with_same_group {
    my ( $self, $number_of_vms_with_same_group_per_host ) = @_;
    my $minimum = 100000000000;
    foreach my $host (keys %$number_of_vms_with_same_group_per_host) {
        $minimum = $number_of_vms_with_same_group_per_host->{$host} if ($number_of_vms_with_same_group_per_host->{$host} < $minimum);
        #print STDERR "DEBUG: host \"$host\" owns $number_of_vms_with_same_group_per_host->{$host} vms of same group.\n";
    }
    return $minimum;
}

1;
