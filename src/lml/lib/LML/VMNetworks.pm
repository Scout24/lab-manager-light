use strict;
use warnings;

package LML::VMNetworks;

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
                                                         startConnected    => 1
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

# find all networks related to this vm
# ====================================
sub find_networks {
    my %args = @_;
    my @vm_networks;
    my $catchall_network = undef;
    # get the configured hostname pattern for later comparision
    my $hostname_pattern_extracted = undef;
    my $hostname_pattern = $args{hostname_pattern};
    if ( $args{vm_name} =~ /($hostname_pattern)/ ) {
        $hostname_pattern_extracted = $1;
    }

    # get all networks, which the selected esx host can see
    my $full_network_list = Vim::get_views( mo_ref_array => $args{host_view}->network );

    # go through each network the esx host can see
    my $network_pattern = $args{network_pattern};
    foreach (@$full_network_list) {
        # get the configured network pattern
        
        my $network_pattern_extracted = undef;
        if ( $_->name =~ /($network_pattern)/ ) {
            $network_pattern_extracted = $1;
        }
        # if the hostname pattern matches the network pattern, take it
        if (     defined $network_pattern_extracted
             and defined $hostname_pattern_extracted
             and $network_pattern_extracted eq $hostname_pattern_extracted )
        {
            # push the generated card spec to our array for network cards
            push( @vm_networks, create_nic( network => $_ ) );

            # else check if we have the catchall network, if yes rembember it
        } elsif ( $_->name eq $args{catchall_network} ) {
            $catchall_network = $_;
        }
    }

    # add a nic connected to the catchall network
    if ( not @vm_networks and defined $catchall_network ) {
        push( @vm_networks, create_nic( network => $catchall_network ) );
    }

    # now make sure, that the the networks are sorted in the correct order

    # when we finished, return the generated network cards as an array
    return @vm_networks;
}

1;
