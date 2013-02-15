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
our @EXPORT = qw(connect_vi get_vm_data search_vm custom_fields setVmExtraOptsU setVmExtraOptsM setVmCustomValueU setVmCustomValueM);

use VMware::VIRuntime;
use LML::Common;
use Carp;


################ Old Interface #############
#
#
#

# only on VMA
#use VMware::VmaTargetLib;

our %CUSTOMFIELDIDS;    # internal cache for custom field id->name relation

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
    my %VM_DATA;

    # filter out templates
    return %VM_DATA if ( $vm->config->template );

    $VM_DATA{"UUID"} = $vm->config->uuid;
    $VM_DATA{"NAME"} = $vm->name;
    $VM_DATA{"PATH"} = Util::get_inventory_path( $vm, $vm->{vim} );
    my @vm_macs = ();
    foreach my $vm_dev ( @{ $vm->config->hardware->device } ) {
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
                $net = Vim::get_view( mo_ref => new ManagedObjectReference( type => "DistributedVirtualPortgroup", value => $portgroupkey ) )->config->name;

            }

            $VM_DATA{"MAC"}{$mac} = $net;
            push( @vm_macs, { "MAC" => $mac, "NETWORK" => $net } );

        }
    }
    if ( scalar(@vm_macs) ) {
        $VM_DATA{"NETWORKING"} = \@vm_macs;
    }
    if ( $vm->customValue ) {
        foreach my $value ( @{ $vm->customValue } ) {
            $VM_DATA{"CUSTOMFIELDS"}{ $CUSTOMFIELDIDS{ $value->key } } = $value->value;
        }
    }

    # keep entire VM object
    # don't need it at the moment
    #	$VM{$uuid}{OBJECT}=$vm;
    # store relevant extraConfig
    for my $extraConfig ( @{ $vm->config->extraConfig } ) {
        $VM_DATA{EXTRAOPTIONS}{ $extraConfig->key } = $extraConfig->value if ( $extraConfig->key eq "bios.bootDeviceClasses" );
    }
    $VM_DATA{VM_ID} = $vm->{mo_ref}->{value};
    return %VM_DATA;
}

# end retrieve_vm_details

################################ sub #################
##
## walk_mob (<object>,<vm data hash>)
##
## walk down the managed object browser searching for VM and call
## retrieve_vm_details to build up the vm data hash
##
##
sub walk_mob($$);    # define prototype for recursive function

sub walk_mob($$) {
    my $object = shift;
    my $VM     = shift;
    if ( $Util::tracelevel > 1 ) {
        Util::trace( 1, "Examining '" . $object->name . "' [" . Util::get_inventory_path( $object, $object->{vim} ) . "]\n" );
    }

    # walk the children recursively
    if ( $object->can("childEntity") ) {

        # walk in only if there are any children
        if ( $object->childEntity ) {
            foreach my $child ( @{ $object->childEntity } ) {
                walk_mob( Vim::get_view( mo_ref => $child ), $VM );
            }
        }
    }

    # walk into vmFolder (there is always only 1 vmFolder in each Datacenter
    if ( $object->can("vmFolder") ) {
        walk_mob( Vim::get_view( mo_ref => $object->vmFolder ), $VM );
    }

    # if this is an VM, handle it
    if (     $object->can("config")
         and defined( $object->config )
         and $object->config->can("uuid")
         and my $uuid = $object->config->uuid )
    {

        # this seems to be a VM
        my %VM_DATA = retrieve_vm_details($object);
        $VM->{$uuid} = \%VM_DATA;

    }
}

################################ sub #################
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

    # initialize CUSTOMFIELDIDS and retrieve custom fields
    my %fields = custom_fields();

}

################################ sub #################
##
## custom_fields
##
## returns a hash of name->id pairs of defined custom fields
##
sub custom_fields {
    %CUSTOMFIELDIDS = ();    # reset custom field ID cache
    my %CUSTOMFIELDS = ();                                                                                  # empty hash for custom fields
    my $custom_fields_manager = Vim::get_view( mo_ref => Vim::get_service_content->customFieldsManager );

    # iterate over custom field definitions and build hash array with name->ID mappings
    foreach my $field ( @{ $custom_fields_manager->field } ) {
        Util::trace( 2, "Field ID '" . $field->key . "' => '" . $field->name . "'\n" );
        $CUSTOMFIELDS{ $field->name }  = $field->key;
        $CUSTOMFIELDIDS{ $field->key } = $field->name;
    }
    return %CUSTOMFIELDS;
}

################################ sub #################
##
## search_vm ([<list of paths>])
##
##
##
sub search_vm {
    my %VM;

    # collect the virtual machines to work on in @VM
    if (@_) {
        foreach my $path (@_) {
            my $searchindex = Vim::get_view( mo_ref => Vim::get_service_content->searchIndex );
            my $searchresult = $searchindex->FindByInventoryPath( inventoryPath => $path );
            if ($searchresult) {
                walk_mob( Vim::get_view( mo_ref => $searchresult ), \%VM );
            } else {
                die "ERROR: Could not find inventory path '$path'";
            }
        }
    } else {

        # method 3: walk down from the very top
        walk_mob( Vim::get_view( mo_ref => Vim::get_service_content->rootFolder ), \%VM );
    }

    # print results
    if ( $Util::tracelevel > 1 ) {
        print("search_vm result:\n");
        foreach my $uuid ( keys(%VM) ) {
            print("VM=$uuid\n");
            foreach my $key ( keys( %{ $VM{$uuid} } ) ) {
                print("\t$key = $VM{$uuid}{$key}\n");
            }
        }
    }

    return %VM;
}

################################ sub #################
##
## get_vm_data (<uuid>)
##
##
##

sub get_vm_data {
    my $uuid = shift;
    my $object = Vim::find_entity_view( view_type => 'VirtualMachine', filter => { 'config.uuid' => $uuid } );

    # if this is an VM, handle it
    if (     $object
         and defined( $object->config )
         and $object->can("config")
         and $object->config->can("uuid") )
    {

        # this seems to be a VM
        return retrieve_vm_details($object);

    } else {
        return ();    # return empty hash
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
    my $vm    = shift;
    my $key   = shift;
    my $value = shift;
    eval {
        if ($vm)
        {
            $vm->setCustomValue( key => $key, value => $value );
        }
    };
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
            Util::trace( 0, "\n" . $@ . "\n" );
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
    my $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine',
                                         filter    => { "config.uuid" => $uuid } );
    if ($vm_view) {
        return setVmCustomValue( $vm_view, $key, $value );
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