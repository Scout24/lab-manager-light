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

our @ISA = qw(Exporter);
our @EXPORT =
  qw(get_vi_connection get_all_vm_data get_vm_data get_folders get_datastores get_networks get_hosts get_custom_fields setVmExtraOpts setVmBootOrderToNetwork clearVmBootOrder setVmCustomValue perform_destroy perform_poweroff perform_reboot_guest perform_reset perform_poweron);

use VMware::VIRuntime;
use LML::Common;
use Carp;
use Switch;
use Sys::Syslog;

################ Old Interface #############
#
#
#

# only on VMA
#use VMware::VmaTargetLib;

my %CUSTOMFIELDIDS;
my %CUSTOMFIELDS;

my %HOSTS;
my %NETWORKIDS;
my %DATASTOREIDS;
my %FOLDERIDS;

# these properties are relevant for us and should be used in get_view / find_*_view calls as a properties argument to speed up
# the API calls. See http://www.virtuin.com/2012/11/best-practices-for-faster-vsphere-sdk.html and the SDK docs for explanations
my $VM_PROPERTIES = [
                      "name",            "config.name",            "config.uuid", "config.extraConfig", 
                      "config.bootOptions.bootOrder", "config.template", "config.hardware.device", 
                      "customValue", "runtime.host", "parent", "runtime.powerState",
];

################ helpers

# get VirtualMachine view
# Arg 1 can be 
# * VirtualMachine object (VI SDK), fastest as it avoids extra lookup
# * VM Managed Object Reference as string (e.g. vm-1234)
# * VM UUID, slowest as it does an index search
# Remaining args are properties to retrieve, defaults to empty list.


sub _get_vm_view {
    my ($search_vm,@properties) = @_;
    get_vi_connection();

    # search for uuid if uuid is given or assume that we got a moref
    # TODO: Check that the moref is actually a moref object
    my $vm_view;
    if (ref($search_vm) eq "VirtualMachine") {
        $vm_view = $search_vm;
    }
    elsif ( _is_uuid($search_vm) ) {
        $vm_view = Vim::find_entity_view(
                                          view_type  => 'VirtualMachine',
                                          filter     => { "config.uuid" => $search_vm },
                                          properties => \@properties # this is empty by default
        );
    }
    else {
        $vm_view = Vim::get_view( mo_ref => $search_vm );
    }
    return $vm_view;
}

# run VI SDK code in first arg and parse errors.
# Croaks error message with hint from second arg

sub _check_success (&@) {
    # See http://stackoverflow.com/questions/6101005/how-to-create-a-perl-subroutine-that-accepts-a-block-of-code
    my $code = \&{shift @_};
    my ($message) = @_;
    eval { 
        delete local $SIG{'__DIE__'}; # ignore other die handlers, see perldoc -f eval
        $code->();
    };
    if ($@) {
        my $err = $@;
        $message .= " FAILED at " . join( ":", ( caller(1) )[ 1, 2 ] ) . ":\n";
        if ( ref($err) eq 'SoapFault' ) {
            my $soapfault = $err;
            my $soapfaultclass = ref $soapfault->detail;
            my $soapfaultstring = $soapfault->fault_string;
            switch ($soapfaultclass) {
                Debug(Data::Dumper->Dump([$soapfault->detail]));
                case 'TooManyDevices' {
                    $message .= "Number of virtual devices exceeds the maximum for a given controller.\n" ;
                }
                case 'InvalidDeviceSpec' {
                    $message .= "The Device configuration is not valid\n";
                }
                case 'FileAlreadyExists' {
                    $message .= "Operation failed because file already exists\n";
                }
                case 'InvalidPowerState' {
                    my $requestedState = $soapfault->detail->requestedState->val;
                    my $existingState = $soapfault->detail->existingState->val;
                    $message .= "Operation failed because VM is $existingState while it should be $requestedState\n";
                }
                case 'ToolsUnavailable' {
                    $message .= "Operation failed because VMware Tools are not running in the VM\n";
                }
                else {
                    $message .= "Operation failed because of $soapfaultclass ($soapfaultstring)\n";
                }
            }
        } else {
            $message .= $@;
        }
        warn($message);
        return 0;
    }
    return 1;
}

# return if arg looks like a UUID
sub _is_uuid {
    my ($text) = @_;
    if ($text) {
        my $hex  = qr([A-Fa-f0-9]);
        # If you name your VMs with something that looks like a UUID but is not the UUID of the VM then
        # you successfully shot yourself in the foot. This sub will never find your VMS.
        return $text =~ qr(^$hex{8}-$hex{4}-$hex{4}-$hex{4}-$hex{12}$);
    } else {
        return 0;
    }
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
    get_networks();
    get_folders();
    # filter out anything that is not a VM
    return %VM_DATA unless ( ref($vm) eq "VirtualMachine" );
    # filter out templates
    return %VM_DATA
      unless ( $vm->get_property("config.template") eq "false" or $vm->get_property("config.template") eq "0" );

    $VM_DATA{UUID} = $vm->get_property("config.uuid");
    $VM_DATA{NAME} = $vm->get_property("name");
    $VM_DATA{POWERSTATE} = $vm->get_property("runtime.powerState")->val;
    $VM_DATA{PATH} = _get_folder($vm);
    # store moref
    $VM_DATA{VM_ID} = $vm->{mo_ref}->{value};
    my @vm_macs = ();
    Debug( "Reading VM " . $VM_DATA{"UUID"} . " (" . $VM_DATA{"NAME"} . "): " . $VM_DATA{"PATH"} );
    foreach my $vm_dev ( @{ $vm->get_property("config.hardware.device") } ) {
        if ( $vm_dev->can("macAddress") and defined( $vm_dev->macAddress ) ) {
            my $mac = $vm_dev->macAddress;
            my $net;
            if ( $vm_dev->backing->can("deviceName") ) {

                # no distributed vSwitch
                $net = $vm_dev->backing->deviceName;
            }
            elsif (     $vm_dev->backing->can("port")
                    and $vm_dev->backing->port->can("portgroupKey")
                    and my $portgroupkey = $vm_dev->backing->port->portgroupKey )
            {

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

                if ( defined $NETWORKIDS{$portgroupkey} ) {
                    $net = $NETWORKIDS{$portgroupkey}->{name};
                }
                else {
                    Debug(   "VM "
                           . $VM_DATA{"NAME"} . " ("
                           . $VM_DATA{VM_ID}
                           . ") mac $mac has unresolvable network '$portgroupkey' connected" );
                    $net = "";
                }
            }
            else {
                Debug( "VM " . $VM_DATA{"NAME"} . " (" . $VM_DATA{VM_ID} . ") mac $mac has no network connected" );
                # dump vm_dev to network label for debugging
                $net = "";
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
    $VM_DATA{"OBJECT"} = $vm;
    
    # store relevant extraConfig
    for my $extraConfig ( @{ $vm->get_property("config.extraConfig") } ) {
        $VM_DATA{"EXTRAOPTIONS"}{ $extraConfig->key } = $extraConfig->value
          if ( $extraConfig->key eq "bios.bootDeviceClasses" );
    }
=pod
# bootOrder contains a list that looks like this:
[
   bless( {
             "deviceKey" => 4000
          }, 'VirtualMachineBootOptionsBootableEthernetDevice' )
]
See https://www.vmware.com/support/developer/converter-sdk/conv50_apireference/vim.vm.BootOptions.BootableDevice.html
for details about these classes. Here we only care about the class type and ignore the device key info.
=cut
    my @bootOrder = $vm->get_property("config.bootOptions.bootOrder") ? @{$vm->get_property("config.bootOptions.bootOrder")} : ();

    @bootOrder = map {
            my %class_name_mapping = (
                "VirtualMachineBootOptionsBootableEthernetDevice","net",
                "VirtualMachineBootOptionsBootableCdromDevice","cdrom",
                "VirtualMachineBootOptionsBootableDiskDevice","disk",
                "VirtualMachineBootOptionsBootableFloppyDevice","floppy"
                );
            my $class = ref;
            $class_name_mapping{$class};
        } @bootOrder;
    $VM_DATA{"BOOTORDER"} = \@bootOrder;
    # store ESX host
    my $host_id = $vm->get_property("runtime.host")->value;
    $VM_DATA{"HOST"} = defined $HOSTS{$host_id} ? $HOSTS{ $vm->get_property("runtime.host")->value }->{name} : "INVALID HOST";
    #print STDERR Data::Dumper->Dump([\%VM_DATA],[qw(VM_DATA)]);
    return \%VM_DATA;
}

# end retrieve_vm_details

############################### sub #################
##
## get_vi_connection
##
##
##
my $connection = undef;

sub get_vi_connection() {
    # connection setup needs to happen only once
    return $connection if ($connection);
    # NOTE: This will eat up all arguments that come AFTER the --arg things.
    # Placing e.g. --verbose as last argument avoids this behaviour.
    Opts::parse();

    # TODO: the validate call seems to query for VI credentials
    #   even though they are not required on VMA
    #   fix so that it won't do that anymore
    eval { Opts::validate(); };
    croak("Could not validate VI options: $@") if ($@);

    #   eval {
    #       my @targets = VmaTargetLib::enumerate_targets;
    #       # TODO: walk through all available VI systems, not only the first one
    #       $targets[0]->login()
    #   };
    eval { $connection = Util::connect(); };
    croak("Could not connect to vSphere, SDK error message:\n$@") if ($@);
    Debug("Connected to vSphere");
    openlog( "lab-manager-light", 'nofatal', 'user' );
    syslog( 'info', "VI connect |%s|", join( "|", ( caller(1) )[ 1, 2, 3 ] ) );
    closelog();
    return $connection;
}

################################ sub #################
##
## get_custom_fields
##
## returns a hash of name->id pairs of defined custom fields
##
sub get_custom_fields {

    unless ( scalar( keys %CUSTOMFIELDS ) ) {
        get_vi_connection();
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

    unless ( scalar( keys %DATASTOREIDS ) ) {
        get_vi_connection();
        my $datastoreEntityViews = Vim::find_entity_views(
            view_type    => "Datastore",
            begin_entity => Vim::get_service_content()->rootFolder,
            # not using properties => because we need various properties and their sub-properties.
        );
        foreach my $e ( @{$datastoreEntityViews} ) {
            #Debug( Data::Dumper->Dump( [ $e ], [ "Datastore" ] ) );
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
                "vm"        => [ map { $_->{value} } @{ $e->{vm} } ],
                "freespace" => $e->{summary}->{freeSpace}, # Bytes
                "capacity"  => exists( $e->{info}->{vmfs} )
                ? $e->{info}->{vmfs}->{capacity} # Bytes
                : "NOT YET IMPLEMENTED for " . $e->{info}->{url},
            };
        }
    }
    #Debug( Data::Dumper->Dump( [ \%DATASTOREIDS ], ["DATASTOREIDS"] ) );
    return \%DATASTOREIDS;
}

################################ sub #################
##
## get_networks
##
## returns a hash of id->data for networks
##

sub get_networks {
    unless ( scalar( keys %NETWORKIDS ) ) {
        get_vi_connection();
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
                                                         properties   => [ "name", "host" ] );
        foreach my $e ( @{$networkEntityViews} ) {
            #Debug( Data::Dumper->Dump( [ $e ], [ "Network" ] ) );
            my $id = $e->{mo_ref}->value;
            $NETWORKIDS{$id} = {
                                 "id"    => $id,
                                 "type"  => $e->{mo_ref}->type,
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
                                                             properties   => [ "name", "host", "key" ] );

        foreach my $e ( @{$dvPortGroupEntityViews} ) {
            #Debug( Data::Dumper->Dump( [$e], ["DistributedVirtualPortgroup"] ) );
            # DVPortgroups are mapped by key and NOT by moref, we found this out when we migrated ESX servers to a new vCenter server.
            # Here we mask this internal behaviour and use the key as and id. Let's hope that the keys are unique.
            # TODO: Notice that keys are not unique and do something about it.
            my $id = $e->get_property("key");
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
## get_folders
##
## returns id->data hashref for folders
##

sub get_folders {
    unless ( scalar keys %FOLDERIDS ) {
        get_vi_connection();
        # collect all object types that could be part of a folder hierarchy
        my $folderViews          = Vim::find_entity_views( view_type => "Folder",          properties => [ "name", "parent" ] );
        my $datacenterViews      = Vim::find_entity_views( view_type => "Datacenter",      properties => [ "name", "parent" ] );
        my $computeResourceViews = Vim::find_entity_views( view_type => "ComputeResource", properties => [ "name", "parent" ] );
        %FOLDERIDS = (
            map {
                $_->{mo_ref}->{value} => {
                    name   => $_->{name},
                    type   => $_->{mo_ref}->{type},
                    parent => $_->{parent}->{value},
                    id     => $_->{mo_ref}->{value},
                    # the following is used only temporarily to debug errors in our get_full_path routine.
                    #vim_path => Util::get_inventory_path( $_, $_->{vim} )
                  }
              } @$folderViews,
            @$datacenterViews,
            @$computeResourceViews,
        );

        # since we retrieved all the information about the folders we can calculate the
        # path much faster than Util::get_inventory_path which uses online calls.
        sub get_full_path {
            my ( $f, $folderids ) = @_;
            if ( defined $f->{parent} ) {
                if ( defined $folderids->{ $f->{parent} } ) {
                    #print STDERR "Calling for ".$f->{parent}.", parent of ".$f->{name}."\n";
                    #return get_full_path($folderids->{$f->{parent}},$folderids)."/".$f->{name};
                    my $parentpath = get_full_path( $folderids->{ $f->{parent} }, $folderids );
                    $parentpath .= "/" if ($parentpath);    # add path separator only if parentpath given,
                                                            # get_inventory_path also returns paths withouth leading /
                    return $parentpath . $f->{name};
                }
                else {
                    croak "Cannot find folder data for " . $f->{parent} . ", parent of " . $f->{name} . "\n";
                }
            }
            else {
                return "";
            }
        }

        foreach my $f ( values %FOLDERIDS ) {
            $f->{path} = get_full_path( $f, \%FOLDERIDS );
        }

        #  FOLDERIDS is now a hash like this:
        #  "datacenter-21" => {
        #                       "name" => "Berlin",
        #                       "parent" => "group-d1",
        #                       "path" => "Berlin",
        #                       "type" => "Datacenter"
        #                     },
        #  "group-d1" => {
        #                  "name" => "Datencenter",
        #                  "parent" => undef,
        #                  "path" => "",
        #                  "type" => "Folder"
        #                },
        #  "group-h23" => {ComputeResource
        #                   "name" => "host",
        #                   "parent" => "datacenter-21",
        #                   "path" => "Berlin/host",
        #                   "type" => "Folder"
        #                 },
        #  "group-n25" => {
        #                   "name" => "network",
        #                   "parent" => "datacenter-21",
        #                   "path" => "Berlin/network",
        #                   "type" => "Folder"
        #                 },
        #  "group-s24" => {
        #                   "name" => "datastore",
        #                   "parent" => "datacenter-21",
        #                   "path" => "Berlin/datastore",
        #                   "type" => "Folder"
        #                 },
        #  "group-v1003" => {
        #                     "name" => "webservers",
        #                     "parent" => "group-v294",
        #                     "path" => "Berlin/vm/test-systems/webservers",
        #                     "type" => "Folder"
        #                   },
        #  "group-v1004" => {
        #                     "name" => "appservers",
        #                     "parent" => "group-v294",
        #                     "path" => "Berlin/vm/test-systems/appservers",
        #                     "type" => "Folder"
        #                   },
        #  parent == undef means root object

    }
    return \%FOLDERIDS;
}

sub _get_folder ($) {
    # get folder of vm
    my ($obj) = @_;
    get_folders;
    if ( defined $obj->{parent}->{value} ) {
        if ( defined $FOLDERIDS{ $obj->{parent}->{value} } ) {
            return $FOLDERIDS{ $obj->{parent}->{value} }->{path};
        }
        else {
            return "NO FOLDER DATA FOUND FOR " . $obj->{parent}->{value};
        }
    }
    else {
        return "OBJECT HAS NO parent ATTRIBUTE";
    }
}
################################ sub #################
##
## get_hosts
##
## returns a hash of id->data blocks for ESX host info
##
sub get_hosts {

    get_vi_connection();

    unless ( scalar( keys %HOSTS ) ) {
        # initialize HOSTS if they don't contain data
        %HOSTS = ();
        my $entityViews = Vim::find_entity_views(
                    view_type    => "HostSystem",
                    begin_entity => Vim::get_service_content()->rootFolder,
                    properties   => [
                                    "runtime.inMaintenanceMode", "hardware.systemInfo.uuid", "name", "config.product", "summary.quickStats",
                                    "summary.hardware", "overallStatus", "network", "datastore", "vm", "parent",
                    ] );
        foreach my $e ( @{$entityViews} ) {
            my $product    = $e->get_property("config.product");
            my $quickStats = $e->get_property("summary.quickStats");
            my $hardware   = $e->get_property("summary.hardware");
            $HOSTS{ $e->{mo_ref}->value } = {
                id      => $e->{mo_ref}->value,
                uuid    => $e->get_property("hardware.systemInfo.uuid"),
                name    => $e->{name},
                product => { fullName => $product->{fullName}, },
                stats   => {
                    # the fairness values are -1 if the host is not part of a cluster. We set it to 1000 so that it will rank badly
                    distributedCpuFairness =>
                      ( exists( $quickStats->{distributedCpuFairness} ) && $quickStats->{distributedCpuFairness} > -1 )
                    ? $quickStats->{distributedCpuFairness}
                    : 1000,
                    distributedMemoryFairness =>
                      ( exists( $quickStats->{distributedMemoryFairness} ) && $quickStats->{distributedMemoryFairness} > -1 )
                    ? $quickStats->{distributedMemoryFairness}
                    : 1000,
                    overallCpuUsage    => $quickStats->{overallCpuUsage},
                    overallMemoryUsage => $quickStats->{overallMemoryUsage},
                },
                hardware => {
                    totalCpuMhz => $hardware->{cpuMhz} * $hardware->{numCpuCores},
                    memorySize  => int( $hardware->{memorySize} / 1024 / 1024 )
                    ,          # strangely the value from the API does not divide cleanly by 1024^2
                    vendor => $hardware->{vendor},
                    model  => $hardware->{model},
                },
                status => {
                    overallStatus => $e->get_property("overallStatus")->{val},
                    # active means that the host can accept new VMs
                    # host must not be in maintenance mode
                    active => $e->get_property("runtime.inMaintenanceMode") eq "false" ? 1 : 0,
                },
                networks   => [ map { $_->{value} } @{ $e->get_property("network")   || [] } ],  # use empty array if host has no networks
                datastores => [ map { $_->{value} } @{ $e->get_property("datastore") || [] } ],  # use empty array if host has no datastores
                vms        => [ map { $_->{value} } @{ $e->get_property("vm")        || [] } ],  # use empty array if host has no VMs
                path => _get_folder($e),
            };
        }
    }
    return \%HOSTS;
}

################################ sub #################
##
## get_vm_data (<uuid|name>)
##
##
##

sub get_vm_data {
    my $search_vm = shift;
    get_vi_connection();
    # search by uuid if we are given something that looks like a uuid
    my $filter = _is_uuid($search_vm) ? 'config.uuid' : 'config.name';
    my $result = Vim::find_entity_view(
                                        view_type  => 'VirtualMachine',
                                        filter     => { $filter => $search_vm },
                                        properties => $VM_PROPERTIES
    );
    # find_entity_view returns the first object found if there are several.
    return retrieve_vm_details($result);
}

################################ sub #################
##
## get_all_vm_data (<uuid>)
##
##
##

sub get_all_vm_data {
    my %filter = @_;
    get_vi_connection();
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
    }
    else {
        return {};
    }
}

#
#
#
#
############################### sub #################
##
## setVmExtraOpts (<VM-ish>,<option key>,<option value>)
##
##
sub setVmExtraOpts {
    my ($search_vm,$key,$value) = @_;
    my $vm_view = _get_vm_view($search_vm);
    if ($vm_view) {
        return _check_success {
            my $vm_config_spec = VirtualMachineConfigSpec->new( extraConfig => [ 
                OptionValue->new( key => $key, value => $value ), 
            ] );
            $vm_view->ReconfigVM( spec => $vm_config_spec );
        } "Setting VM Extra Opts $key=$value";
    }
    else {
        return 0;
    }
}


############################### sub #################
##
## setVmBootOrderToNetwork (<VM-ish>)
##
## Set config.bootOptions.bootOrder to the first network card
##
sub setVmBootOrderToNetwork {
    my ($search_vm)  = @_;
    my $vm_view = _get_vm_view($search_vm,"config.hardware.device");
    if ($vm_view) {
        return _check_success {
                my $nickey;
                my @devices = @{ $vm_view->get_property("config.hardware.device") };
                foreach(@devices) {
                    if($_->isa('VirtualEthernetCard')) {
                        $nickey = $_->key;
                        last;
                    }
                }

                if (defined($nickey)) {
                    my @bootOrder = (
                        VirtualMachineBootOptionsBootableEthernetDevice->new(deviceKey => $nickey)
                    );

                    my $bootOptions = VirtualMachineBootOptions->new(bootOrder => \@bootOrder);
                    my $spec = VirtualMachineConfigSpec->new(bootOptions => $bootOptions);
                    $vm_view->ReconfigVM( spec => $spec );
                } else {
                    die "Could not find any Network card";
                }
            } "Setting Boot Order";
    }
    else {
        return 0;
    }
}

sub clearVmBootOrder {
    my ($search_vm)  = @_;
    my $vm_view = _get_vm_view($search_vm);
    if ($vm_view) {
        return _check_success {
                
                my $bootOptions = VirtualMachineBootOptions->new(bootOrder => [
                    VirtualMachineBootOptionsBootableDevice->new()
                ]);
                my $spec = VirtualMachineConfigSpec->new(bootOptions => $bootOptions);
                $vm_view->ReconfigVM( spec => $spec );
            } "Clearing Boot Order";
    }
    else {
        return 0;
    }
}

############################### sub #################
##
## setVmCustomValue (<VM like thing>,<option key>,<option value>)
##
##
sub setVmCustomValue {
    my ($search_vm,$key,$value) = @_;
    my $vm_view = _get_vm_view($search_vm);
    if ($vm_view) {
        return _check_success { 
                $vm_view->setCustomValue( key => $key, value => $value ) 
            } "Setting Custom Value $key=$value";
    }
    else {
        return 0;
    }
}


sub perform_reboot_guest {
    my ($vm) = @_;
    my $vm_view = _get_vm_view($vm);
    return $vm_view ? _check_success { $vm_view->RebootGuest(); } "Rebooting Guest" : 0;
}

sub perform_reset {
    my ($vm) = @_;
    my $vm_view = _get_vm_view($vm);
    return $vm_view ? _check_success { $vm_view->ResetVM(); } "Hard Restarting VM" : 0;
}

sub perform_destroy {
    my ($vm) = @_;
    my $vm_view = _get_vm_view($vm);
    return $vm_view ? _check_success { $vm_view->Destroy(); } "Destroying VM" : 0;
}

sub perform_poweroff {
    my ($vm) = @_;
    my $vm_view = _get_vm_view($vm);
    if ($vm_view) {
        my $result = _check_success { $vm_view->PowerOffVM(); } "Powering Off VM";
        return $result;
    } else {
        return 0;
    }
}

sub perform_poweron {
    my ($vm) = @_;
    my $vm_view = _get_vm_view($vm);
    return $vm_view ? _check_success { $vm_view->PowerOnVM(); } "Powering On VM" : 0;
}


END {
    if ( defined &Util::disconnect ) {
        # if we have VMware code loaded then disconnect when dying.
        Util::disconnect();
        Debug("Disconnected from vSphere");
    }
}

1;
