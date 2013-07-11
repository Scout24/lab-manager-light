use strict;
use warnings;

package LML::VMnetworks;

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

# Find all networks related to this vm
# ====================================
sub find_networks {
    my %args = @_;
    my @vm_networks;
    my @vm_networks_temp;
    my $catchall_network = undef;
    my $network_pattern  = $args{network_pattern};
    # Get the configured hostname pattern for later comparision
    my $hostname_pattern_extracted = undef;
    my $hostname_pattern           = $args{hostname_pattern};
    if ( $args{vm_name} =~ /($hostname_pattern)/i ) {
        $hostname_pattern_extracted = $1;
    }

    # Get all networks, which the selected esx host can see
    my $full_network_list = Vim::get_views( mo_ref_array => $args{host_view}->network );

    foreach (@$full_network_list) {
        # Get the configured network pattern

        my $network_pattern_extracted = undef;
        if ( $_->name =~ /($network_pattern)/i ) {
            $network_pattern_extracted = $1;
        }
        # If the hostname pattern matches the network pattern, take it
        if (     defined $network_pattern_extracted
             and defined $hostname_pattern_extracted
             and lc($network_pattern_extracted) eq lc($hostname_pattern_extracted) )
        {
            # Push the generated card spec to our array for network cards
            my %wrapped = wrap_network_spec_for_sorting( create_nic( network => $_ ), $_->name );
            push( @vm_networks_temp, \%wrapped );

            # Else check if we have the catchall network, if yes rembember it
        } elsif ( $_->name eq $args{catchall_network} ) {
            $catchall_network = $_;
        }
    }
    # Add a nic connected to the catchall network
    if ( not @vm_networks_temp and defined $catchall_network ) {
        my $nic = create_nic( network => $catchall_network );
        my %wrapped = wrap_network_spec_for_sorting( $nic, $catchall_network );
        push( @vm_networks_temp, \%wrapped );
    }

    # Now make sure, that the the networks are sorted in the correct order
    sort_networks(@vm_networks_temp);
    foreach (@vm_networks_temp) {
        push( @vm_networks, unwrap_network_spec($_) );
    }

    # When we finished, return the generated network cards as an array
    return @vm_networks;
}

sub is_backend {
    my $network = shift;
    my %network = %{$network};
    return $network{"name"} =~ /_BE_/i;
}

sub compare {
    my $first             = shift;
    my $is_first_backend  = is_backend($first);
    my $second            = shift;
    my $is_second_backend = is_backend($second);
    return 1  if ( $is_second_backend and not $is_first_backend );
    return -1 if ( $is_first_backend  and not $is_second_backend );
    return 0;
}

sub sort_networks {
    return sort { compare( $a, $b ) } @_;
}

sub wrap_network_spec_for_sorting {
    my $spec = shift;
    my $name = shift;
    return (
             "name" => $name,
             "spec" => $spec
    );
}

sub unwrap_network_spec {
    my $wrapped = shift;
    my %wrapped = %{$wrapped};
    return $wrapped{"spec"};
}

1;
