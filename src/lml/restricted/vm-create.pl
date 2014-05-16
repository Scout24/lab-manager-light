#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib glob "{/opt/vmware/,/usr/lib/vmware-}vcli/?pps";    # the ? makes sure that only existing paths will match.
use lib "$FindBin::RealBin/../lib";

$Util::script_version = "1.0";

use CGI ':standard';
use VMware::VIRuntime;
use AppUtil::XMLInputUtil;
use AppUtil::HostUtil;
use AppUtil::VMUtil;
use LWP::Simple qw(get);
use Getopt::Long;
use LML::VMware;
use LML::VMnetworks;
use LML::VMcreate::VMproperties;
use LML::Lab;
use LML::DHCP;

# Only for debugging
use Data::Dumper;
#print "DEBUG: ".Data::Dumper->Dump([%{$vm_config_spec}])."\n";

use LML::Config;
my $C = new LML::Config();

my $lab           = new LML::Lab( $C->labfile );
my $vm_properties = new LML::VMcreate::VMproperties( $C, $lab );
my @vms           = $vm_properties->generate_vms_array();

create_vms(@vms);

# compose error output related to the execution context
# =====================================================
sub error {
    my $message = shift;

    # print html header before anything else if CGI is used
    if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '500 Error while processing' );
        print $message;
        print STDERR $message . "\n";
    }
    else {
        print $message . "\n";
    }
    exit 1;
}

# compose a success output related to caller
# ==========================================
sub success {
    my $uuid    = shift;
    my $message = shift;

    # print html header before anything else if CGI is used
    if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '200 vm created' ) . $uuid;
    }
    else {
        print "New VM has UUID $uuid\n";
    }
}

# This subroutine parses the input xml file to retrieve all the
# parameters specified in the file and passes these parameters
# to create_vm subroutine to create a single virtual machine
# =============================================================
sub create_vms {
    my @vms = @_;

    # go through each dataset and create a vm with the given specs
    foreach (@vms) {
        create_vm($_);
    }
}

# create a virtual machine
# ========================
sub create_vm {
    my $args = shift;
    my @vm_devices;

    if (defined $lab->get_vm($$args{vmname})) {
        error("The VM with name \"$$args{vmname}\" already exist.");
    }

    # connect to VMware
    get_vi_connection();

    my $host_view = Vim::find_entity_view( view_type => 'HostSystem',
                                           filter    => { 'name' => $$args{vmhost} } );

    if ( !$host_view ) {
        error("Host '$$args{vmhost}' not found");
    }

    my %ds_info = HostUtils::get_datastore(
                                            host_view => $host_view,
                                            datastore => $$args{datastore},
                                            disksize  => $$args{disksize} );

    if ( $ds_info{mor} eq 0 ) {
        if ( $ds_info{name} eq 'datastore_error' ) {
            error("Datastore $$args{datastore} not available.");
        }
        if ( $ds_info{name} eq 'disksize_error' ) {
            error("The free space available is less than the specified disksize.");
        }
    }

    my $ds_path                     = "[" . $ds_info{name} . "]";
    my $controller_vm_dev_conf_spec = create_conf_spec();
    my $disk_vm_dev_conf_spec       = create_virtual_disk( ds_path => $ds_path, disksize => $$args{disksize} );

    # Get all networks, which are related to this vm
    my $networks = new LML::VMnetworks( $C, $host_view );
    my @vm_nics = $networks->generate_vm_nic_device_specs( $$args{vmname}, $$args{force_network} );

    # check the success and add the found networks
    if (@vm_nics) {
        push @vm_devices, @vm_nics;

    }
    else {
        error("No networks for host '$$args{vmname}' found");
    }

    push @vm_devices, $controller_vm_dev_conf_spec;
    push @vm_devices, $disk_vm_dev_conf_spec;

    my $files = VirtualMachineFileInfo->new(
                                             logDirectory      => undef,
                                             snapshotDirectory => undef,
                                             suspendDirectory  => undef,
                                             vmPathName        => $ds_path
    );

    my $vm_config_spec = VirtualMachineConfigSpec->new(
                                                        name              => $$args{vmname},
                                                        memoryMB          => int $$args{memory},
                                                        files             => $files,
                                                        numCoresPerSocket => int $$args{num_cpus},
                                                        numCPUs           => int $$args{num_cpus},
                                                        guestId           => $$args{guestid},
                                                        deviceChange      => \@vm_devices
    );

    my $datacenter_views = Vim::find_entity_views( view_type => 'Datacenter',
                                                   filter    => { name => $$args{datacenter} } );

    unless (@$datacenter_views) {
        error("Datacenter '$$args{datacenter}' not found");
    }

    if ( $#{$datacenter_views} != 0 ) {
        error("Datacenter '$$args{datacenter}' not unique");
    }

    my $datacenter           = shift @$datacenter_views;
    my $datacenter_vm_folder = Vim::get_view( mo_ref => $datacenter->vmFolder );
    my $comp_res_view        = Vim::get_view( mo_ref => $host_view->parent );

    # create the folder regardless its already there
    #create_folder( folder => $args{target_folder} );

    # get the wished folder
    my $target_folder_view;
    my @found = split /\//x, $$args{target_folder};
    # remove any empty lines
    @found = grep /\S/x, @found;
    get_folder(
                folder      => $datacenter_vm_folder,
                found       => \@found,
                target_view => \$target_folder_view
    );

    my $vm_ref;
    if ( defined $target_folder_view ) {
        eval { $vm_ref = $target_folder_view->CreateVM( config => $vm_config_spec, pool => $comp_res_view->resourcePool ); };
        if ($@) {
            if ( ref($@) eq 'SoapFault' ) {
                if ( ref( $@->detail ) eq 'PlatformConfigFault' ) {
                    error( "Invalid VM configuration: " . ${ $@->detail }{'text'} );
                }
                elsif ( ref( $@->detail ) eq 'InvalidDeviceSpec' ) {
                    error( "Invalid Device configuration: " . ${ $@->detail }{'property'} );
                }
                elsif ( ref( $@->detail ) eq 'DatacenterMismatch' ) {
                    error("DatacenterMismatch, the input arguments had entities that did not belong to the same datacenter");
                }
                elsif ( ref( $@->detail ) eq 'HostNotConnected' ) {
                    error("Unable to communicate with the remote host, since it is disconnected");
                }
                elsif ( ref( $@->detail ) eq 'InvalidState' ) {
                    error("The operation is not allowed in the current state");
                }
                elsif ( ref( $@->detail ) eq 'DuplicateName' ) {
                    error("Virtual machine '$$args{vmname}' already exists in folder '$$args{target_folder}'");
                }
                else {
                    error("CreateVM failed:\n".Data::Dumper([$@],['$@']));
                }
            }
            else {
                error("CreateVM failed:\n$@\n");
            }
        }
        error("CreateVM did not return us a mo_ref") unless ( defined $vm_ref and ref($vm_ref) eq 'ManagedObjectReference' );
    }
    else {
        error("Invalid Folder $$args{target_folder} specified");
    }

    my $vm_view = Vim::get_view( mo_ref => $vm_ref );

    # first thing add VM data to lab.conf so that it can be deleted through LML even if the following operations fail.
    my $HOSTS      = get_hosts;
    my $NETWORKS   = get_networks;
    my $DATASTORES = get_datastores;
    my $FOLDERS    = get_folders;
    my $rw_lab     = new LML::Lab( $C->labfile, 1 );
    # first update the info about ESX hosts
    $rw_lab->update_hosts($HOSTS);
    $rw_lab->update_networks($NETWORKS);
    $rw_lab->update_datastores($DATASTORES);
    $rw_lab->update_folders($FOLDERS);
    $rw_lab->update_vm( new LML::VM( $vm_view->config->uuid ) );
    # Should also have set dns_domain and the custom fields from below etc., but works also without.
    # When the VM boots via pxelinux.pl we will write the correct values to lab.conf
    if ( not $rw_lab->write_file( "for just now created " . $$args{vmname} . " (" . $vm_view->config->uuid . ")" ) ) {
        # NOT dying here on purpose to give vm-create a chance to finish starting the VM.
        warn "Strangely writing LAB produced a 0-byte file.\n";
    }
    if ( $rw_lab->vms_to_update ) {
        # rewrite the DHCP configuration with the new data
        my @errors = LML::DHCP::UpdateDHCP( $C, $rw_lab );
        if (@errors) {
            error("Could not update DHCP configuration:\n".join("\n",@errors));
        }
    }

    # set the custom fields with defined values
    set_custom_fields( custom_fields => $$args{custom_fields},
                       vm_view       => $vm_view );
    # finally switch on the virtual machine
    eval { $vm_view->PowerOnVM(); };
    # handle errors
    if ($@) {
        if (ref($@) eq 'SoapFault' ) {
            if ( ref( $@->detail ) eq 'NoCompatibleHost' ) {
                    error("PowerOnVM: Virtual machine '$$args{vmname}' is not compatible with the host '$$args{vmhost}'");
                }
                else {
                    error("Could not power on VM:\n".Data::Dumper->Dump([$@],['$@']));
                }
        }
        else {
            error("Could not power on VM:\n".Data::Dumper->Dump([$@],['$@']));
        }
    }

    # if everything went find give an success status
    success( $vm_view->config->uuid );
}

#sub create_folder {
#    my %args = @_;
#
#    my $folder      = $args{folder};
#    #$datacenter_vm_folder->CreateFolder( name => $args{target_folder} );
#}

# iterate through folders of datacenter
sub get_folder {
    my %args = @_;

    my $folder      = $args{folder};
    my $found       = $args{found};
    my $target_view = $args{target_view};

    # quit if the target was already found
    not @{$found} and ${$target_view} and return;

    # are we in the target folder?
    if ( $folder->name eq ${$found}[0] ) {
        # cut the first found array element, if we are in that folder
        shift @{$found};
        # do we have a hit?
        if ( not @{$found} ) {
            ${$target_view} = $folder;
            return;
        }
    }

    # quit on no childs
    $folder->can("childEntity") or return;

    # quit if we get errors on requesting the child entry
    my $children = $folder->childEntity || return;

    # go through each found child
    for my $child ( @{$children} ) {
        # ignore virtual machines
        next if $child->type eq 'VirtualMachine';

        # call this function on child to start the game again
        get_folder(
                    folder      => Vim::get_view( mo_ref => $child ),
                    found       => $found,
                    target_view => $target_view
        );
    }
}

# set the custom fields used by lab manager light
# ===============================================
sub set_custom_fields {
    my %args = @_;
    get_vi_connection();

    # get view to service object
    my $customFieldsManager = Vim::get_view( mo_ref => Vim::get_service_content()->customFieldsManager );
    # only if there are fields defined
    if ( defined $customFieldsManager->{field} ) {
        my $fields = $customFieldsManager->{field};
        # go through each custom field, which is defined globally
        my $key;
        foreach my $field (@$fields) {
            # go through each configured custom field (in input xml)
            foreach ( keys %{ $args{custom_fields} } ) {
                # if we are at the right field, use its key to modify the custom field in vm
                if ( $field->name eq $_ ) {
                    my $key   = $field->key;
                    my $value = ${ $args{custom_fields} }{ $field->name };
                    next unless ( defined $value );    # skip unset values
                    eval { $customFieldsManager->SetField( entity => $args{vm_view}, key => $key, value => $value ); };
                    if ($@) {
                        croak("Could not set custom field '$key' to '$value':\n$@\n");
                    }
                }
            }
        }
    }
}

# create virtual device config spec for controller
# ================================================
sub create_conf_spec {
    my $controller = ParaVirtualSCSIController->new(
                                                     key       => 0,
                                                     device    => [0],
                                                     busNumber => 0,
                                                     sharedBus => VirtualSCSISharing->new('noSharing') );

    my $controller_vm_dev_conf_spec = VirtualDeviceConfigSpec->new( device    => $controller,
                                                                    operation => VirtualDeviceConfigSpecOperation->new('add') );

    return $controller_vm_dev_conf_spec;
}

# create virtual device config spec for disk
# ==========================================
sub create_virtual_disk {
    my %args     = @_;
    my $ds_path  = $args{ds_path};
    my $disksize = $args{disksize};

    my $disk_backing_info = VirtualDiskFlatVer2BackingInfo->new( diskMode => 'persistent',
                                                                 fileName => $ds_path );

    my $disk = VirtualDisk->new(
                                 backing       => $disk_backing_info,
                                 controllerKey => 0,
                                 key           => 0,
                                 unitNumber    => 0,
                                 capacityInKB  => $disksize
    );

    my $disk_vm_dev_conf_spec = VirtualDeviceConfigSpec->new(
                                                              device        => $disk,
                                                              fileOperation => VirtualDeviceConfigSpecFileOperation->new('create'),
                                                              operation     => VirtualDeviceConfigSpecOperation->new('add') );
    return $disk_vm_dev_conf_spec;
}

