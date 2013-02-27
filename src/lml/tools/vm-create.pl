#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use XML::LibXML;
use AppUtil::XMLInputUtil;
use AppUtil::HostUtil;
use Data::Dumper;

$Util::script_version = "1.0";

my %opts = (
    filename => {
        type     => "=s",
        help     => "The location of the input xml file",
        required => 0,
        default  => "../sampledata/vmcreate.xml",
    },
    schema => {
        type     => "=s",
        help     => "The location of the schema file",
        required => 0,
        default  => "../schema/vmcreate.xsd",
    }
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();
create_vms();
Util::disconnect();

# This subroutine parses the input xml file to retrieve all the
# parameters specified in the file and passes these parameters
# to create_vm subroutine to create a single virtual machine
# =============================================================
sub create_vms {
    my $parser = XML::LibXML->new();
    my $tree   = $parser->parse_file(Opts::get_option('filename'));
    my $root   = $tree->getDocumentElement;
    my @vms    = $root->findnodes('Virtual-Machine');

    foreach ( @vms ) {
        # default values will be used in case
        # the user do not specify some parameters
        my $memory = 256;  # in MB
        my $num_cpus = 1;
        my $guestid = 'rhel6_64Guest';
        my $disksize = 4096;  # in KB
        my $nic_poweron = 1;
        my %custom_fields;

        # If the properties are specified, the default values are not used.
        if ($_->findvalue('Guest-Id')) {
            $guestid = $_->findvalue('Guest-Id');
        }
        if ($_->findvalue('Disksize')) {
            $disksize = $_->findvalue('Disksize');
        }
        if ($_->findvalue('Memory')) {
            $memory = $_->findvalue('Memory');
        }
        if ($_->findvalue('Number-of-Processor')) {
            $num_cpus = $_->findvalue('Number-of-Processor');
        }
        if ($_->findvalue('Nic-Poweron')) {
            $nic_poweron = $_->findvalue('Nic-Poweron');
        }
        # go through the section of Custom-Values
        if ($_->findvalue('Custom-Values')) {
            for my $entry ($_->findnodes('Custom-Values/Value')) {
                $custom_fields{$entry->getAttribute('name')} = $entry->textContent();
            }
        }

        create_vm( vmname        => $_->findvalue('Name'),
                   vmhost        => $_->findvalue('Host'),
                   datacenter    => $_->findvalue('Datacenter'),
                   guestid       => $guestid,
                   datastore     => $_->findvalue('Datastore'),
                   disksize      => $disksize,
                   memory        => $memory,
                   num_cpus      => $num_cpus,
                   nic_network   => $_->findvalue('Nic-Network'),
                   nic_poweron   => $nic_poweron,
                   custom_fields => \%custom_fields,
                   target_folder => $_->findvalue('Target-Folder') );
    }
}

# create a virtual machine
# ========================
sub create_vm {
    my %args = @_;
    my @vm_devices;
    my $host_view = Vim::find_entity_view( view_type => 'HostSystem',
                                           filter    => {'name' => $args{vmhost}} );

    if ( ! $host_view ) {
        Util::trace(0, "\nError creating VM '$args{vmname}': "
                     . "Host '$args{vmhost}' not found\n");
        return;
    }

    my %ds_info = HostUtils::get_datastore( host_view => $host_view,
                                            datastore => $args{datastore},
                                            disksize  => $args{disksize} );

    if ($ds_info{mor} eq 0) {
        if ($ds_info{name} eq 'datastore_error') {
            Util::trace(0, "\nError creating VM '$args{vmname}': "
                         . "Datastore $args{datastore} not available.\n");
            return;
        }
        if ($ds_info{name} eq 'disksize_error') {
            Util::trace(0, "\nError creating VM '$args{vmname}': The free space "
                         . "available is less than the specified disksize.\n");
            return;
        }
    }

    my $ds_path = "[" . $ds_info{name} . "]";
    my $controller_vm_dev_conf_spec = create_conf_spec();
    my $disk_vm_dev_conf_spec =
        create_virtual_disk(ds_path => $ds_path, disksize => $args{disksize});

    my %net_settings = get_network( network_name => $args{nic_network},
                                    poweron => $args{nic_poweron},
                                    host_view => $host_view );

    # check for errors
    if ( $net_settings{'error'} eq 0 ) {
        push(@vm_devices, $net_settings{'network_conf'});
    } elsif ($net_settings{'error'} eq 1) {
        Util::trace( 0, "\nError creating VM '$args{vmname}': "
                      . "Network '$args{nic_network}' not found\n" );
        return;
    }

    push( @vm_devices, $controller_vm_dev_conf_spec );
    push( @vm_devices, $disk_vm_dev_conf_spec );

    my $files = VirtualMachineFileInfo->new( logDirectory      => undef,
                                             snapshotDirectory => undef,
                                             suspendDirectory  => undef,
                                             vmPathName        => $ds_path );

    my $vm_config_spec = VirtualMachineConfigSpec->new( name         => $args{vmname},
                                                        memoryMB     => $args{memory},
                                                        files        => $files,
                                                        numCPUs      => $args{num_cpus},
                                                        guestId      => $args{guestid},
                                                        deviceChange => \@vm_devices );

    my $datacenter_views =
        Vim::find_entity_views ( view_type => 'Datacenter',
                                 filter    => { name => $args{datacenter}} );

    unless (@$datacenter_views) {
        Util::trace(0, "\nError creating VM '$args{vmname}': "
                     . "Datacenter '$args{datacenter}' not found\n");
        return;
    }

    if ( $#{$datacenter_views} != 0 ) {
        Util::trace(0, "\nError creating VM '$args{vmname}': "
                     . "Datacenter '$args{datacenter}' not unique\n");
        return;
    }

    my $datacenter = shift @$datacenter_views;
    my $datacenter_vm_folder = Vim::get_view(mo_ref => $datacenter->vmFolder);
    my $comp_res_view  = Vim::get_view(mo_ref => $host_view->parent);

    # get the wished folder
    my $target_folder_view;
    my @found = split(/\//,$args{target_folder});
    # remove any empty lines
    @found = grep(/\S/, @found);
    get_folder( folder      => $datacenter_vm_folder,
                found       => \@found,
                target_view => \$target_folder_view );

    eval {
        $target_folder_view->CreateVM( config => $vm_config_spec,
                                       pool   => $comp_res_view->resourcePool );
        Util::trace(0, "\nSuccessfully created virtual machine: "
                      ."'$args{vmname}' under host $args{vmhost}\n");
    };

    if ( $@ ) {
        Util::trace(0, "\nError creating VM '$args{vmname}': ");
        if (ref($@) eq 'SoapFault') {
            if (ref($@->detail) eq 'PlatformConfigFault') {
                Util::trace(0, "Invalid VM configuration: "
                             . ${$@->detail}{'text'} . "\n");
            } elsif (ref($@->detail) eq 'InvalidDeviceSpec') {
                Util::trace(0, "Invalid Device configuration: "
                             . ${$@->detail}{'property'} . "\n");
            } elsif (ref($@->detail) eq 'DatacenterMismatch') {
                Util::trace(0, "DatacenterMismatch, the input arguments had entities "
                             . "that did not belong to the same datacenter\n");
            } elsif (ref($@->detail) eq 'HostNotConnected') {
                Util::trace(0, "Unable to communicate with the remote host,"
                             . " since it is disconnected\n");
            } elsif (ref($@->detail) eq 'InvalidState') {
                Util::trace(0, "The operation is not allowed in the current state\n");
            } elsif (ref($@->detail) eq 'DuplicateName') {
                Util::trace(0, "Virtual machine already exists.\n");
            } else {
                Util::trace(0, "\n" . $@ . "\n");
            }
        } else {
            Util::trace(0, "\n" . $@ . "\n");
        }
    }

    # only begin to fill the custom fields, if no error occured
    if ( not $@ ) {
        set_custom_fields( vmname        => $args{vmname},
                           custom_fields => $args{custom_fields} );
    }
}

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
        shift(@{$found});
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
        get_folder( folder      => Vim::get_view( mo_ref => $child),
                    found       => $found,
                    target_view => $target_view );
    }
}

# set the custom fields used by lab manager light
# ===============================================
sub set_custom_fields {
    my %args = @_;

    # get view to service object
    my $customFieldsManager =
        Vim::get_view( mo_ref => Vim::get_service_content()->customFieldsManager );
    # only if there are fields defined
    if (defined $customFieldsManager->{field}) {
        my $fields = $customFieldsManager->{field};

        # get  view of the previous created vm
        my $vm = Vim::find_entity_view( view_type => 'VirtualMachine',
                                        filter    => {"config.name" => $args{vmname}});

        # go through each custom field, which is defined globally
        my $key;
        foreach my $field ( @$fields ) {
            # go through each configured custom field (in input xml)
            foreach ( keys %{$args{custom_fields}}) {
                # if we are at the right field, use its key to modify the custom field in vm
                if( $field->name eq $_ ) {
                    $customFieldsManager->SetField( entity => $vm,
                                                    key    => $field->key,
                                                    value  => ${$args{custom_fields}}{$field->name} );
                }
            }
        }
    }
}

# create virtual device config spec for controller
# ================================================
sub create_conf_spec {
    my $controller =
        ParaVirtualSCSIController->new( key       => 0,
                                        device    => [0],
                                        busNumber => 0,
                                        sharedBus => VirtualSCSISharing->new('noSharing') );

    my $controller_vm_dev_conf_spec =
        VirtualDeviceConfigSpec->new( device    => $controller,
                                      operation => VirtualDeviceConfigSpecOperation->new('add') );

    return $controller_vm_dev_conf_spec;
}

# create virtual device config spec for disk
# ==========================================
sub create_virtual_disk {
    my %args = @_;
    my $ds_path = $args{ds_path};
    my $disksize = $args{disksize};

    my $disk_backing_info =
        VirtualDiskFlatVer2BackingInfo->new(diskMode => 'persistent',
                                            fileName => $ds_path);

    my $disk = VirtualDisk->new( backing       => $disk_backing_info,
                                 controllerKey => 0,
                                 key           => 0,
                                 unitNumber    => 0,
                                 capacityInKB  => $disksize );

    my $disk_vm_dev_conf_spec =
        VirtualDeviceConfigSpec->new( device        => $disk,
                                      fileOperation => VirtualDeviceConfigSpecFileOperation->new('create'),
                                      operation     => VirtualDeviceConfigSpecOperation->new('add'));
    return $disk_vm_dev_conf_spec;
}

# get network configuration
# =========================
#print "DEBUG: ".Data::Dumper->Dump([%{$data}])."\n";
sub get_network {
    my %args = @_;
    my $network_name = $args{network_name};
    my $poweron = $args{poweron};
    my $host_view = $args{host_view}; #DEBUG0
    my $network = undef;
    my $unit_num = 1;  # 1 since 0 is used by disk

    if($network_name) {
        my $network_list = Vim::get_views( mo_ref_array => $host_view->network );

        foreach (@$network_list) {
            if($network_name eq $_->name) {
                $network = $_;

                my $dvs_view = Vim::get_view( mo_ref => $network->config->distributedVirtualSwitch );

                my $backing_port = DistributedVirtualSwitchPortConnection->new(
                    portgroupKey => $network->key,
                    switchUuid   => $dvs_view->uuid
                );

                my $nic_backing_info = VirtualEthernetCardDistributedVirtualPortBackingInfo->new(
                    port    => $backing_port 
                );

                my $vd_connect_info =
                    VirtualDeviceConnectInfo->new( allowGuestControl => 1,
                                                   connected => 0,
                                                   startConnected => $poweron );

                my $nic = VirtualVmxnet3->new( backing     => $nic_backing_info,
                                               key         => 0,
                                               unitNumber  => $unit_num,
                                               addressType => 'generated',
                                               connectable => $vd_connect_info );

                my $nic_vm_dev_conf_spec =
                    VirtualDeviceConfigSpec->new( device => $nic,
                                                  operation => VirtualDeviceConfigSpecOperation->new('add') );
                return (error => 0, network_conf => $nic_vm_dev_conf_spec);
            }
        }
        if (!defined($network)) {
            # no network found
            return (error => 1);
        }
    }
    # default network will be used
    return (error => 2);
}

# check the XML file
# =====================
sub validate {
    my $valid = XMLValidation::validate_format( Opts::get_option('filename') );
    if ($valid == 1) {
        $valid = XMLValidation::validate_schema( Opts::get_option('filename'),
                                                 Opts::get_option('schema') );
        if ($valid == 1) {
            $valid = check_missing_value();
        }
    }
    return $valid;
}

# check missing values of mandatory fields
# ========================================
sub check_missing_value {
    my $valid = 1;
    my $filename = Opts::get_option('filename');
    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_file($filename);
    my $root = $tree->getDocumentElement;

    # defect 223162
    if($root->nodeName eq 'Virtual-Machines') {
        my @vms = $root->findnodes('Virtual-Machine');
        foreach (@vms) {
            if (!$_->findvalue('Name')) {
                Util::trace(0, "\nERROR in '$filename':\n<Name> value missing " .
                               "in one of the VM specifications\n");
                $valid = 0;
            }
            if (!$_->findvalue('Host')) {
                Util::trace(0, "\nERROR in '$filename':\n<Host> value missing " .
                               "in one of the VM specifications\n");
                $valid = 0;
            }
            if (!$_->findvalue('Datacenter')) {
                Util::trace(0, "\nERROR in '$filename':\n<Datacenter> value missing " .
                               "in one of the VM specifications\n");
                $valid = 0;
            }
        }
    } else {
        Util::trace(0, "\nERROR in '$filename': Invalid root element ");
        $valid = 0;
    }
    return $valid;
}

__END__

=head1 NAME

vm-create.pl - Create virtual machines according to the specifications
               provided in the input XML file.

=head1 SYNOPSIS

 vm-create.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface for creating one
or more new virtual machines based on the parameters specified in the
input valid XML file. The syntax of the XML file is validated against the
specified schema file.

=head1 OPTIONS

=over

=item B<filename>

Optional. The location of the XML file which contains the specifications of the virtual
machines to be created. If this option is not specified, then the default
file 'vmcreate.xml' will be used from the "../sampledata" directory. The user can use
this file as a referance to create there own input XML files and specify the file's
location using <filename> option.

=item B<schema>

Optional. The location of the schema file against which the input XML file is
validated. If this option is not specified, then the file 'vmcreate.xsd' will
be used from the "../schema" directory. This file need not be modified by the user.

=back

=head2 INPUT PARAMETERS

The parameters for creating the virtual machine are specified in an XML
file. The structure of the input XML file is:

   <Virtual-Machines>
      <Virtual-Machine>
         <!--Several parameters like machine name, guest OS, memory etc-->
      </Virtual-Machine>
      .
      .
      .
      <Virtual-Machine>
      </Virtual-Machine>
   </Virtual-Machines>

Following are the input parameters:

=over

=item B<Name>

Required. Name of the virtual machine to be created.

=item B<Host>

Required. Name of the host.

=item B<Datacenter>

Required. Name of the datacenter.

=item B<Guest-Id>

Optional. Guest operating system identifier. Default: 'winXPProGuest'.

=item B<Datastore>

Optional. Name of the datastore. Default: Any accessible datastore with free
space greater than the disksize specified.

=item B<Disksize>

Optional. Capacity of the virtual disk (in KB). Default: 4096

=item B<Memory>

Optional. Size of virtual machine's memory (in MB). Default: 256

=item B<Number-of-Processor>

Optional. Number of virtual processors in a virtual machine. Default: 1

=item B<Nic-Network>

Optional. Network name. Default: Any accessible network.

=item B<Nic-Poweron>

Optional. Flag to specify whether or not to connect the device
when the virtual machine starts. Default: 1

=back

=head1 EXAMPLE

Create five new virtual machines with the following configuration:

 Machine 1:
      Name                            : server01
      Host                            : esx01.domain.loc
      Datacenter                      : SGI
      Guest Os                        : Red Hat 6 (64bit)
      Datastore                       : datastore1
      Disk size                       : 8 GB
      Memory                          : 1 GB
      Number of CPUs                  : 1
      Network                         : VM Network
      nic_poweron flag                : 1
      Custom Field (Contact User ID)  : user1
      Custom Field (Expires)          : 01.01.2014
      Custom Field (Force Boot)       : ON
      Custom Field (Force Boot Target): server
      Target-Folder                   : /Users/user1/

To create five virtual machines as specified, use the following input XML file:

 <?xml version="1.0"?>
 <Virtual-Machines>
    <Virtual-Machine>
       <Name>server01</Name>
       <Host>esx01.domain.loc</Host>
       <Datacenter>SGI</Datacenter>
       <Guest-Id>rhel6_64Guest</Guest-Id>
       <Datastore>esx04:datastore1</Datastore>
       <Disksize>8388608</Disksize>
       <Memory>1024</Memory>
       <Number-of-Processor>1</Number-of-Processor>
       <Nic-Network>VM Network</Nic-Network>
       <Nic-Poweron>1</Nic-Poweron>
       <Custom-Values>
          <Value name="Contact User ID">user1</Value>
          <Value name="Expires">01.01.2014</Value>
          <Value name="Force Boot">ON</Value>
          <Value name="Force Boot Target">server</Value>
       </Custom-Values>
       <Target-Folder>/Users/user1/</Target-Folder>
   </Virtual-Machine>
 </Virtual-Machines>

The command to run the vm-create script is:

 vm-create.pl --url https://vsphere.domain.loc/sdk/webService
             --username administrator --password mypassword
             --filename create_vm.xml --schema schema.xsd

The script continues to create the next virtual machine even if
a previous machine creation process failed.

=head1 SUPPORTED PLATFORMS

Create operation work with VMware VirtualCenter 2.0 or later.
