#
# vmware functions go here
#

package LML::VMware;

use strict;
use warnings;
use Exporter;
use vars qw(
  $VERSION
  @ISA
  @EXPORT
);

our @ISA    = qw(Exporter);
our @EXPORT = qw(connect_vi get_all_vm_data get_vm_data get_datastores get_networks get_hosts get_hostids get_custom_fields setVmExtraOptsU setVmExtraOptsM setVmCustomValueU setVmCustomValueM perform_destroy perform_poweroff perform_reboot perform_reset);

use VMware::VIRuntime;
use LML::Common;
use Carp;

################ Old Interface #############
#
#
#

# only on VMA
#use VMware::VmaTargetLib;

my %CUSTOMFIELDIDS;
my %CUSTOMFIELDS;

my %HOSTIDS;
my %HOSTS;
my %NETWORKIDS;
my %DATASTOREIDS;

# these properties are relevant for us and should be used in get_view / find_*_view calls as a properties argument to speed up
# the API calls. See http://www.virtuin.com/2012/11/best-practices-for-faster-vsphere-sdk.html and the SDK docs for explanations
my $VM_PROPERTIES = [ "name", "config.name", "config.uuid", "config.extraConfig", "config.template", "config.hardware.device", "customValue", "runtime.host", ];

my %DVP_PORT_GROUP_NAMES;
# lookup and cache port group names of DistributedVirtualSwitches
sub dvp_to_name($) {
    my $portgroupkey = shift;
    if ( !exists $DVP_PORT_GROUP_NAMES{$portgroupkey} ) {
        $DVP_PORT_GROUP_NAMES{$portgroupkey} = Vim::get_view(
                                                              mo_ref => new ManagedObjectReference(
                                                                                                    type  => "DistributedVirtualPortgroup",
                                                                                                    value => $portgroupkey
                                                              ),
                                                              properties => ["config.name"]
        )->get_property("config.name");
        Debug("Cached $portgroupkey = $DVP_PORT_GROUP_NAMES{$portgroupkey}");
    }
    return $DVP_PORT_GROUP_NAMES{$portgroupkey};
}
################################ sub #################
##
## retrieve_vm_details (<vm>)
##
## read details about this vm (an object of the VirtualMachine type) and return a hash with the data that is relevant for us
##
##
##
sub retrieve_vm_details ($) {
    my $vm = shift;
    ##Debug( Data::Dumper->Dump( [ $vm ], ["vm"] ) ) if ($isDebug);
    my %VM_DATA;

    # initialize lookup tables
    get_hosts();
    get_custom_fields();
    # filter out anything that is not a VM
    return %VM_DATA unless ( ref($vm) eq "VirtualMachine" );
    # filter out templates
    return %VM_DATA
      unless ( $vm->get_property("config.template") eq "false" or $vm->get_property("config.template") eq "0" );

    $VM_DATA{"UUID"} = $vm->get_property("config.uuid");
    $VM_DATA{"NAME"} = $vm->get_property("name");
    $VM_DATA{"PATH"} = Util::get_inventory_path( $vm, $vm->{vim} );
    my @vm_macs = ();
    Debug( "Reading VM " . $VM_DATA{"UUID"} . " (" . $VM_DATA{"NAME"} . "): " . $VM_DATA{"PATH"} );
    foreach my $vm_dev ( @{ $vm->get_property("config.hardware.device") } ) {
        if ( $vm_dev->can("macAddress") and defined( $vm_dev->macAddress ) ) {
            my $mac = $vm_dev->macAddress;
            my $net;
            if ( $vm_dev->backing->can("deviceName") ) {

                # no distributed vSwitch
                $net = $vm_dev->backing->deviceName;
            } else {

                # this is probably a distributed vSwitch, need to retrieve infos by following the vSwitch UUID

=pod
  DB<34> x $vm_dev
0  VirtualPCNet32=HASH(0xa8ca558)
   'addressType' => 'assigned'
   'backing' => VirtualEthernetCardDistributedVirtualPortBackingInfo=HASH(0xa86dce8)
      'port' => DistributedVirtualSwitchPortConnection=HASH(0xa7dad90)
         'connectionCookie' => 1799741339
         'portKey' => 257
         'portgroupKey' => 'dvportgroup-288'
         'switchUuid' => 'a4 4a 13 50 16 1d e3 48-ad 44 65 f2 fa f9 77 72'
   'connectable' => VirtualDeviceConnectInfo=HASH(0xa853820)
      'allowGuestControl' => 1
      'connected' => 0
      'startConnected' => 1
      'status' => 'untried'
   'controllerKey' => 100
   'deviceInfo' => Description=HASH(0xa8a75a8)
      'label' => 'Netzwerkadapter 1'
      'summary' => 'vm.device.VirtualPCNet32.DistributedVirtualPortBackingInfo.summary'
   'key' => 4000
   'macAddress' => '00:50:56:b7:00:0f'
   'unitNumber' => 7
   'wakeOnLanEnabled' => 1



=cut

                my $portgroupkey = $vm_dev->backing->port->portgroupKey;
                $net = dvp_to_name($portgroupkey);
            }

            $VM_DATA{"MAC"}{$mac} = $net;
            push @vm_macs, { "MAC" => $mac, "NETWORK" => $net };

        }
    }
    if ( scalar @vm_macs ) {
        $VM_DATA{"NETWORKING"} = \@vm_macs;
    }
    if ( $vm->customValue ) {
        foreach my $value ( @{ $vm->customValue } ) {
            $VM_DATA{"CUSTOMFIELDS"}{ $CUSTOMFIELDIDS{ $value->key } } = $value->value;
        }
    }

    # keep entire VM object
    # don't need it at the moment
    if ($isDebug) {
        $VM_DATA{OBJECT} = $vm;
    }
    # store relevant extraConfig
    for my $extraConfig ( @{ $vm->get_property("config.extraConfig") } ) {
        $VM_DATA{EXTRAOPTIONS}{ $extraConfig->key } = $extraConfig->value
          if ( $extraConfig->key eq "bios.bootDeviceClasses" );
    }

    # store ESX host
    $VM_DATA{HOST} = $HOSTIDS{ $vm->get_property("runtime.host")->value };

    # store moref
    $VM_DATA{VM_ID} = $vm->{mo_ref}->{value};
    return \%VM_DATA;
}

# end retrieve_vm_details

############################### sub #################
##
## connect_vi
##
##
##

sub connect_vi() {

    # NOTE: This will eat up all arguments that come AFTER the --arg things.
    # Placing e.g. --verbose as last argument avoids this behaviour.
    Opts::parse();

    # TODO: the validate call seems to query for VI credentials
    #	even though they are not required on VMA
    #	fix so that it won't do that anymore
    eval { Opts::validate(); };
    croak("Could not validate VI options: $@") if ($@);

    #	eval {
    #		my @targets = VmaTargetLib::enumerate_targets;
    #		# TODO: walk through all available VI systems, not only the first one
    #		$targets[0]->login()
    #	};
    eval { Util::connect(); };
    croak("Could not connect to VI: $@") if ($@);
    Debug("Connected to vSphere");

}

################################ sub #################
##
## get_custom_fields
##
## returns a hash of name->id pairs of defined custom fields
##
sub get_custom_fields {
    unless ( scalar( keys(%CUSTOMFIELDS) ) ) {
        # initialize CUSTOMFIELDIDS and retrieve custom fields if they are not set
        %CUSTOMFIELDIDS = ();
        %CUSTOMFIELDS   = ();
        my $custom_fields_manager = Vim::get_view( mo_ref => Vim::get_service_content->customFieldsManager );

        # don't die on the border case that there are not custom fields defined.
        if (     $custom_fields_manager
             and $custom_fields_manager->can("field")
             and scalar( @{ $custom_fields_manager->field } ) )
        {
            # iterate over custom field definitions and build hash array with name->ID mappings
            foreach my $field ( @{ $custom_fields_manager->field } ) {
                #Debug( Data::Dumper->Dump( [ $field ], [ "field" ] ) );
                # we care only about VM custom fields and not about Global custom fields
                next unless ( $field->managedObjectType eq "VirtualMachine" );
                $CUSTOMFIELDS{ $field->name }  = $field->key;
                $CUSTOMFIELDIDS{ $field->key } = $field->name;
            }
        }
    }
    return \%CUSTOMFIELDS;
}

################################ sub #################
##
## get_datastores
##
## returns a hash of id->data for datastores
##

sub get_datastores {
    unless ( scalar( keys(%DATASTOREIDS) ) ) {
        my $datastoreEntityViews = Vim::find_entity_views(
            view_type    => "Datastore",
            begin_entity => Vim::get_service_content()->rootFolder,
            # not using properties => because we need various properties and their sub-properties.
        );
        foreach my $e ( @{$datastoreEntityViews} ) {
            my $id = $e->{mo_ref}->value;
            $DATASTOREIDS{$id} = {
                "id"    => $id,
                "name"  => $e->{name},
                "hosts" => [
                    map { $_->{key}->{value} } grep {
                        # filter datastores to those that are really usable right now
                        # TODO: Test degraded scenarios and find out if this is a good idea or not
                        $_->{mountInfo}->{accessible}
                          and $_->{mountInfo}->{mounted}
                          and $_->{mountInfo}->{accessMode} eq 'readWrite'
                      } @{ $e->{host} }
                ],
                "vm" => [
                    map {
                        $_->{value}
                      } @{ $e->{vm} }
                ],
                "freespace" => $e->{info}->{freeSpace},
                "capacity"  => exists( $e->{info}->{vmfs} )
                ? $e->{info}->{vmfs}->{capacity}
                : "NOT YET IMPLEMENTED for " . $e->{info}->{url},
            };
        }
    }
    Debug( Data::Dumper->Dump( [ \%DATASTOREIDS ], ["DATASTOREIDS"] ) );
    return \%DATASTOREIDS;
}

################################ sub #################
##
## get_networks
##
## returns a hash of id->data for networks
##

sub get_networks {
    unless ( scalar( keys(%NETWORKIDS) ) ) {
        # $networkEntityViews is an array of this:
        #Network=HASH(0x51f57e0)
        #      'host' => ARRAY(0x5207ad0)
        #         0  ManagedObjectReference=HASH(0x51e8600)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1060'
        #      'mo_ref' => ManagedObjectReference=HASH(0x51e83d8)
        #         'type' => 'Network'
        #         'value' => 'network-1329'
        #      'name' => 'VLAN-Trunk'
        my $networkEntityViews = Vim::find_entity_views(
                                                         view_type    => "Network",
                                                         begin_entity => Vim::get_service_content()->rootFolder,
                                                         properties   => [ "name", "host" ]
        );
        foreach my $e ( @{$networkEntityViews} ) {
            #Debug( Data::Dumper->Dump( [ $e ], [ "Network" ] ) );
            my $id = $e->{mo_ref}->value;
            $NETWORKIDS{$id} = {
                                 "id"    => $id,
                                 "name"  => $e->{name},
                                 "hosts" => [ map { $_->{value} } @{ $e->{host} } ],
            };
        }
        # $dvPortGroupEntityViews is an array of this:
        #DistributedVirtualPortgroup=HASH(0x6ddf398)
        #      'host' => ARRAY(0x6dd6dc8)
        #         0  ManagedObjectReference=HASH(0x6e57750)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1606'
        #         1  ManagedObjectReference=HASH(0x5e92600)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1608'
        #         2  ManagedObjectReference=HASH(0x6e54e80)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1598'
        #         3  ManagedObjectReference=HASH(0x6e577b0)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1633'
        #         4  ManagedObjectReference=HASH(0x5e9ba50)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1615'
        #         5  ManagedObjectReference=HASH(0x6dd6048)
        #            'type' => 'HostSystem'
        #            'value' => 'host-1637'
        #      'mo_ref' => ManagedObjectReference=HASH(0x5e99738)
        #         'type' => 'DistributedVirtualPortgroup'
        #         'value' => 'dvportgroup-2675'
        #      'name' => '3801_BE_DEVNIC_DYN'
        my $dvPortGroupEntityViews = Vim::find_entity_views(
                                                             view_type    => "DistributedVirtualPortgroup",
                                                             begin_entity => Vim::get_service_content()->rootFolder,
                                                             properties   => [ "name", "host" ]
        );

        foreach my $e ( @{$dvPortGroupEntityViews} ) {
            #Debug( Data::Dumper->Dump( [$e], ["DistributedVirtualPortgroup"] ) );
            my $id = $e->{mo_ref}->value;
            $NETWORKIDS{$id} = {
                                 "id"    => $id,
                                 "name"  => $e->{name},
                                 "hosts" => [ map { $_->{value} } @{ $e->{host} } ],
            };
        }
        #Debug( Data::Dumper->Dump( [ \%NETWORKIDS ], ["NETWORKIDS"] ) );
    }
    return \%NETWORKIDS;
}

################################ sub #################
##
## get_hosts
##
## returns a hash of name->data blocks for ESX host info
##
sub get_hosts {

    # initialize %NETWORKIDS
    get_networks();

    # initialize %DATASTOREIDS
    get_datastores();

    unless ( scalar( keys(%HOSTS) ) ) {
        # initialize HOSTIDS and HOSTS if they don't contain data
        %HOSTS   = ();
        %HOSTIDS = ();
        my $entityViews = Vim::find_entity_views(
                                                  view_type    => "HostSystem",
                                                  begin_entity => Vim::get_service_content()->rootFolder,
                                                  properties   => [ "name", "config.product", "summary.quickStats", "summary.hardware" ]
        );
        foreach my $e ( @{$entityViews} ) {
            #Debug( Data::Dumper->Dump( [ $e ], [ "host" ] ) );
            $HOSTIDS{ $e->{mo_ref}->value } = $e->{name};
            Debug( "Reading ESX Host " . $e->{name} );
            $HOSTS{ $e->{name} } = {
                                     "id"         => $e->{mo_ref}->value,
                                     "name"       => $e->{name},
                                     "product"    => { %{ $e->get_property("config.product") } },
                                     "quickStats" => { %{ $e->get_property("summary.quickStats") } },
                                     "hardware"   => { %{ $e->get_property("summary.hardware") } },
                                     "networks"   => [],
                                     "datastores" => [],
            };
            # some systems have extra info which remains blessed after the get_property
            delete( $HOSTS{ $e->{name} }{"hardware"}{"otherIdentifyingInfo"} );
        }

        # add networks to host data
        while ( my ( $nid, $network ) = each %NETWORKIDS ) {
            foreach my $hid ( @{ $network->{hosts} } ) {
                push @{ $HOSTS{ $HOSTIDS{$hid} }{"networks"} }, $network->{"name"};
            }
        }

        # add datastores to host data
        while ( my ( $did, $datastore ) = each %DATASTOREIDS ) {
            foreach my $hid ( @{ $datastore->{hosts} } ) {
                push @{ $HOSTS{ $HOSTIDS{$hid} }{"datastores"} }, $datastore->{"name"};
            }
        }
    }
    return \%HOSTS;
}

sub HostSystemIdentificationInfo::deserialize {
    # this is temporarily here to fix a bug
}
################################ sub #################
##
## get_hosts
##
## returns a hash of name->id pairs of defined custom fields
##
sub get_hostids {

    get_hosts;
    return \%HOSTIDS;
}

################################ sub #################
##
## get_vm_data (<uuid>)
##
##
##

sub get_vm_data {
    my $uuid = shift;
    my $object = Vim::find_entity_view(
                                        view_type  => 'VirtualMachine',
                                        filter     => { 'config.uuid' => $uuid },
                                        properties => $VM_PROPERTIES
    );

    return retrieve_vm_details($object);
}

################################ sub #################
##
## get_all_vm_data (<uuid>)
##
##
##

sub get_all_vm_data {
    my %filter = @_;
    Debug( Data::Dumper->Dump( [ \%filter ], ["filter"] ) ) if (%filter);
    my $entityViews = Vim::find_entity_views(
                                              view_type    => "VirtualMachine",
                                              begin_entity => Vim::get_service_content()->rootFolder,
                                              filter       => \%filter,
                                              properties   => $VM_PROPERTIES
    );
    if ($entityViews) {
        my $results = {};
        foreach my $view (@$entityViews) {
            my $VM;
            if ( exists $view->{"config.uuid"} and $VM = retrieve_vm_details($view) ) {
                $results->{ $view->{"config.uuid"} } = $VM;
            }    # else is probably a template
        }
        return $results;
    } else {
        return {};
    }
}

#
#
#
#
############################### sub #################
##
## setVmExtraOptsU (<uuid of VM>,<option key>,<option value>)
##
##
sub setVmExtraOptsU {
    my $uuid  = shift;
    my $key   = shift;
    my $value = shift;
    eval {
        my $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine',
                                             filter    => { "config.uuid" => $uuid } );
        if ($vm_view) {
            my $vm_config_spec = VirtualMachineConfigSpec->new( extraConfig => [ OptionValue->new( key => $key, value => $value ), ] );
            $vm_view->ReconfigVM( spec => $vm_config_spec );
        }
    };
    if ($@) {
        Util::trace( 0, "\nReconfiguration failed: " );
        if ( ref($@) eq 'SoapFault' ) {
            if ( ref( $@->detail ) eq 'TooManyDevices' ) {
                Util::trace( 0, "\nNumber of virtual devices exceeds " . "the maximum for a given controller.\n" );
            } elsif ( ref( $@->detail ) eq 'InvalidDeviceSpec' ) {
                Util::trace( 0, "The Device configuration is not valid\n" );
                Util::trace( 0, "\nFollowing is the detailed error: \n\n$@" );
            } elsif ( ref( $@->detail ) eq 'FileAlreadyExists' ) {
                Util::trace( 0, "\nOperation failed because file already exists" );
            } else {
                Util::trace( 0, "\n" . $@ . "\n" );
            }
        } else {
            Util::trace( 0, "\n" . $@ . "\n" );
        }
    }
}

############################### sub #################
##
## setVmExtraOptsM (<moref of VM>,<option key>,<option value>)
##
##
sub setVmExtraOptsM {
    my $mo_ref = shift;
    my $key    = shift;
    my $value  = shift;
    eval {
        my $vm_view = Vim::get_view( mo_ref => $mo_ref );
        if ($vm_view) {
            my $vm_config_spec = VirtualMachineConfigSpec->new( extraConfig => [ OptionValue->new( key => $key, value => $value ), ] );
            $vm_view->ReconfigVM( spec => $vm_config_spec );
        }
    };
    if ($@) {
        Util::trace( 0, "\nReconfiguration failed: " );
        if ( ref($@) eq 'SoapFault' ) {
            if ( ref( $@->detail ) eq 'TooManyDevices' ) {
                Util::trace( 0, "\nNumber of virtual devices exceeds " . "the maximum for a given controller.\n" );
            } elsif ( ref( $@->detail ) eq 'InvalidDeviceSpec' ) {
                Util::trace( 0, "The Device configuration is not valid\n" );
                Util::trace( 0, "\nFollowing is the detailed error: \n\n$@" );
            } elsif ( ref( $@->detail ) eq 'FileAlreadyExists' ) {
                Util::trace( 0, "\nOperation failed because file already exists" );
            } else {
                Util::trace( 0, "\n" . $@ . "\n" );
            }
        } else {
            Util::trace( 0, "\n" . $@ . "\n" );
        }
        return 0;
    }
    return 1;
}

############################### sub #################
##
## setVmCustomValue (<VM object>,<option key>,<option value>)
##
##
sub setVmCustomValue {
    my $vm = shift;
    die "vm argument was not a VirtualMachine object!\n" unless ( ref($vm) eq "VirtualMachine" );
    my $key   = shift;
    my $value = shift;
    eval { $vm->setCustomValue( key => $key, value => $value ) };
    if ($@) {
        Util::trace( 0, "\nsetCustomValue($key,$value) failed: " );
        if ( ref($@) eq 'SoapFault' ) {
            if ( ref( $@->detail ) eq 'TooManyDevices' ) {
                Util::trace( 0, "\nNumber of virtual devices exceeds " . "the maximum for a given controller.\n" );
            } elsif ( ref( $@->detail ) eq 'InvalidDeviceSpec' ) {
                Util::trace( 0, "The Device configuration is not valid\n" );
                Util::trace( 0, "\nFollowing is the detailed error: \n\n$@" );
            } elsif ( ref( $@->detail ) eq 'FileAlreadyExists' ) {
                Util::trace( 0, "\nOperation failed because file already exists" );
            } else {
                Util::trace( 0, "\n" . $@ . "\n" );
            }
        } else {
            die $@;
        }
        return 0;
    }
    return 1;
}

############################### sub #################
##
## setVmCustomValueM (<moref of VM>,<option key>,<option value>)
##
##
sub setVmCustomValueM {
    my $mo_ref  = shift;
    my $key     = shift;
    my $value   = shift;
    my $vm_view = Vim::get_view( mo_ref => $mo_ref );
    if ($vm_view) {
        return setVmCustomValue( $vm_view, $key, $value );
    }
}

############################### sub #################
##
## setVmCustomValueU (<uuid of VM>,<option key>,<option value>)
##
##
sub setVmCustomValueU {
    my $uuid  = shift;
    my $key   = shift;
    my $value = shift;
    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []                            # don't need any properties to set custom value
    );
    if ($vm_view) {
        return setVmCustomValue( $vm_view, $key, $value );
    }
}

sub perform_reboot {
    my ($uuid) = @_;

    # Get vm view
    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []                            # don't need any properties to set custom value
    );

    # Did we get an view?
    if ($vm_view) {
        # Reboot the VM
        eval { $vm_view->RebootGuest(); };

        if ($@) {
            Debug("SDK RebootGuest command exited abnormally");
            return 0;
        }

    } else {
        return 0;
    }
}

sub perform_reset {
    my ($uuid) = @_;

    # Get vm view
    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []                            # don't need any properties to set custom value
    );

    # Did we get an view?
    if ($vm_view) {
        # Reboot the VM
        eval { $vm_view->ResetVM(); };

        if ($@) {
            Debug("SDK ResetVM command exited abnormally");
            return 0;
        }

    } else {
        return 0;
    }
}

sub perform_destroy {
    my ($uuid) = @_;

    # Get vm view
    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []                            # don't need any properties to set custom value
    );

    # Did we get an view?
    if ($vm_view) {
        # Destroy the VM
        eval { $vm_view->Destroy(); };

        # Check the success
        if ($@) {
            Debug("SDK destroy command exited abnormally");
            return 0;
        }

    } else {
        return 0;
    }
}

sub perform_poweroff {
    my ($uuid) = @_;

    # Get vm view
    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []                            # don't need any properties to set custom value
    );

    # Did we get an view?
    if ($vm_view) {
        # Reboot the VM
        eval { $vm_view->PowerOffVM(); };

        # Check the success
        if ($@) {
            Debug("SDK PowerOffVM command exited abnormally");
            return 0;
        }

    } else {
        Debug("Could not retrieve vm view for uuid $uuid");
        return 0;
    }
}

END {
    if ( defined &Util::disconnect ) {
        # if we have VMware code loaded then disconnect when dying.
        Util::disconnect();
        Debug("Disconnected from vSphere");
    }
}

1;
