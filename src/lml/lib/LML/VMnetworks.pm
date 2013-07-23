package LML::VMnetworks;

use strict;
use warnings;
use Data::Dumper;

sub new {
    my ( $class, $config, $host_view ) = @_;

    my $self = {
                 config    => $config,
                 host_view => $host_view,
    };
    bless $self, $class;
    return $self;
}

# Find all networks related to this vm
# ====================================

sub find_networks {
    my ( $self, $vm_name, $force_network ) = @_;
    my @network_labels = $self->_find_first_network( $vm_name, $force_network );
    push @network_labels, $self->_find_second_network( $vm_name, @network_labels );

    my @vm_nics = $self->_create_nics_by_network_labels(@network_labels);

    return @vm_nics;
}

sub _find_first_network {
    my ( $self, $vm_name, $force_network ) = @_;
    my @vm_networks_labels;

    # Check if we forced to a network, or if the network should be detected automatically
    if ( defined $force_network and length $force_network ) {
        push @vm_networks_labels, $force_network;
    }
    # Network should be detected automatically
    else {
        # Get the parameters related to network assignment logic
        my @network_search_order = $self->{config}->get_array( "new_vm", "network_search_order" );

        # The search order controls the outer loop
      LOOP:
        foreach my $net_label (@network_search_order) {
            # Use the current net_label as index for the network assignment structure
            foreach my $rule ( $self->{config}->get_array( "network_assignment", $net_label ) ) {
                if ( $vm_name =~ m/$rule$/x ) {
                    push @vm_networks_labels, $net_label;
                    # Set the loop marker to done and quit this loop
                    last LOOP;
                }
            }
        }
    }

    return @vm_networks_labels;
}

sub _find_second_network {
    my ( $self, $vm_name, @network_labels ) = @_;

    # Read out patterns which vm name should match, if the vm should get an 2nd interface
    my @second_interface_patterns = $self->{config}->get_array( "new_vm", "2nd_interface" );
    # Read out the string, which should be appended to indentify the 2nd interface network label
    my $second_interface_suffix = $self->{config}->get( "new_vm", "2nd_interface_suffix" );

    my @second_network_labels = ();

    # Loop through each found pattern and try if the vm name is matching against one
    foreach my $pattern (@second_interface_patterns) {
        # If we found a pattern which is matching, the vm is allowed to get an 2nd interface
        if ( $vm_name =~ m/^$pattern$/x ) {
            # So take every submitted network label, put the configured 2nd_interface_suffix to the labels
            # and create a new array with that labels
            foreach my $network_label (@network_labels) {
                push @second_network_labels, $network_label . $second_interface_suffix;
            }
            # Our work is done here, so break the outer loop
            last;
        }
    }

    # Finally return the array with the generated 2nd interface pendants
    return @second_network_labels;
}

sub _create_nics_by_network_labels {
    my ( $self, @network_labels ) = @_;
    my @vm_nics;

    # After retrieving a full list of networks to be assigned, get the appropriate specs
    # Begin with getting all networks, which the selected esx host can see
    my $full_network_list = Vim::get_views( mo_ref_array => $self->{host_view}->network );

    # Go through each network label. Take this way, because the order is important here!
    foreach my $label (@network_labels) {
        # Now look if the actual label has an pendant in the real world
        foreach my $network (@$full_network_list) {
            if ( $network->name eq $label ) {
                push @vm_nics, _create_nic( network => $network );
                # Because we found the network now, go over to the next label
                last;
            }
        }
    }

    # When we finished, return the generated network cards as an array
    return @vm_nics;
}

# generate a spec of a networkcard
# ================================
sub _create_nic {
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

1;
