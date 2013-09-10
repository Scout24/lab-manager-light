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
        lab                   => $lab,
        config                => $config,
        vm_distribution_cache => {},
        vm_minimum_cache      => {},
        verbose               => $config->get( "lml", "verbose_auto_placement" ),
        group_pattern         => $config->get( "hostrules", "group_pattern" ),

    };

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host, $vm_res ) = @_;

    if ( !defined( $self->{group_pattern} ) ) {
        return 1;    # do not filter if no group pattern was defined
    }

    $vm_res->{name} =~ qr(^$self->{group_pattern}$);
    my $expected_group = $1;
    if ( !defined $expected_group ) {
        return 1;    # do not filter if a group pattern was defined but we can not determine the group of our vm
    }

    my $vm_group_counts        = $self->_get_vm_group_counts( $vm_res, $expected_group );
    my $minimum                = $vm_group_counts->{minimum};
    my $counter_same_vm_groups = $vm_group_counts->{counters}->{ $host->{id} };

    if ( $counter_same_vm_groups > $minimum ) {
        if ( $self->{verbose} ) {
            print STDERR "Removing host " . $host->{name} . ", it has $counter_same_vm_groups VMs matching $expected_group\n";
        }
        return 0;
    }
    else {
        return 1;
    }
}

sub get_name {
    return 'ByGroupReliability';
}

##################################################
# private methods
##################################################

sub _get_vm_group_counts {
    my ( $self, $vm_res, $expected_group ) = @_;

    my $vm_res_id = $vm_res + 0;    # get object address in memory

    if ( !defined $self->{vm_distribution_cache}->{$vm_res_id} ) {
        # fill cache
        my %number_of_vms_with_same_group_per_host = ();

        my @all_vms = $self->{lab}->get_vms();

        # iterate over all esx hosts
        foreach my $host ( $self->{lab}->get_hosts() ) {

            my $host_id                = $host->{id};
            my $host_name              = $host->{name};
            next unless (defined $host_id and defined $host_name); # skip hosts without id and name
            
            my $counter_same_vm_groups = 0;

            # TODO: is there a more perl style to express these nested foreach loops?
            # iterate over all vms on this esx host
            foreach my $vm_id ( @{ $host->{vms} } ) {

# now the bad thing: iterate over all vms (independent from host) and try to find vm with same id, because we do not know the name of the vm
                foreach my $vm (@all_vms) {
                    # is this the vm with a matching id
                    if ( $vm_id eq $vm->vm_id ) {

                        # resolve group of matching vm
                        $vm->name =~ qr(^$self->{group_pattern}$);

                        # if vm group is same, increase the vm counter for this host
                        $counter_same_vm_groups++ if ( $expected_group eq $1 );

                        # break, because we already found our vm
                        last;
                    }

                }

            }
            $number_of_vms_with_same_group_per_host{$host_id} = $counter_same_vm_groups;
            if ( $self->{verbose} ) {
                print STDERR "Host $host_name has $counter_same_vm_groups VMs matching $expected_group\n";
            }
        }
        my $minimum = 100000000000;
        foreach my $host ( keys %number_of_vms_with_same_group_per_host ) {
            $minimum = $number_of_vms_with_same_group_per_host{$host} if ( $number_of_vms_with_same_group_per_host{$host} < $minimum );
        }
        if ( $self->{verbose} ) {
            print STDERR "Minimum VM group count is $minimum\n";
        }
        $self->{vm_distribution_cache}->{$vm_res_id} = { counters => \%number_of_vms_with_same_group_per_host, minimum => $minimum };
    }
    return $self->{vm_distribution_cache}->{$vm_res_id};
}

1;
