package LML::VMnetworks;

use strict;
use warnings;

sub new {
    my ( $class, $config, $host_view ) = @_;

    my $self = {
                 config    => $config,
                 host_view => $host_view,
    };
    bless $self, $class;
    return $self;
}

# generate a spec of a networkcard
# ================================
sub create_nic {
    my %args = @_;

    # get the dv view of the actual network
    my $dvs_view = Vim::get_view( mo_ref => $args{network}->config->distributedVirtualSwitch );

    # create a new "connection" to that dv switch
    my $backing_port = DistributedVirtualSwitchPortConnection->new( portgroupKey => $args{network}->key,
                                                                    switchUuid   => $dvs_view->uuid );

    # new backing info for the network card to be generated
    my $nic_backing_info = VirtualEthernetCardDistributedVirtualPortBackingInfo->new( port => $backing_port );

    # generate basic conditions for the network card
    my $vd_connect_info = VirtualDeviceConnectInfo->new(
                                                         allowGuestControl => 1,
                                                         connected         => 0,
                                                         startConnected    => 1,
    );

    # now generate the network card (just a view atm)
    my $nic = VirtualVmxnet3->new(
                                   backing     => $nic_backing_info,
                                   key         => 0,
                                   unitNumber  => 1,                   # 1 since 0 is used by disk
                                   addressType => 'generated',
                                   connectable => $vd_connect_info
    );

    # convert the generated networkcard view to a spec for adding to a virtual machine
    my $nic_vm_dev_conf_spec = VirtualDeviceConfigSpec->new( device    => $nic,
                                                             operation => VirtualDeviceConfigSpecOperation->new('add') );

    # return the generated spec
    return $nic_vm_dev_conf_spec;
}

# Find all networks related to this vm
# ====================================
sub find_networks {
    my ( $self, $vm_name ) = @_;
    my @vm_nics;
    my @vm_networks_labels;

    # Get the parameters related to network assignment logic
    my @network_search_order = $self->{config}->get_array( "vm_create", "network_search_order" );

    # The search order controls the outer loop
    LOOP:
    foreach my $net_label (@network_search_order) {
        # Use the current net_label as index for the network assignment structure
        foreach my $rule ( $self->{config}->get_array( "network_assignment", $net_label ) ) {
            if ( $vm_name =~ qr{^$rule$}x ) {
                push @vm_networks_labels, $net_label;
                # Set the loop marker to done and quit this loop
                last LOOP;
            }
        }
    }

    # After retrieving a full list of networks to be assigned, get the appropriate specs
    # Begin with getting all networks, which the selected esx host can see
    my $full_network_list = Vim::get_views( mo_ref_array => $self->{host_view}->network );

    # Go through each network, which is assigned to the host vieww
    foreach my $network (@$full_network_list) {
        if ( grep { $_ eq $network->name } @vm_networks_labels ) {
            push @vm_nics, create_nic( network => $network );
        }

        # When we finished, return the generated network cards as an array
        return @vm_nics;
    }
}

1;