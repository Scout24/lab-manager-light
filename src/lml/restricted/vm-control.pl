#!/usr/bin/perl -w
#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#
# Patched by authors:
#     Stefan Neben <stefan.neben@gmail.com>
#

use strict;
use warnings;

use FindBin;
use lib glob("{/opt/vmware/,/usr/lib/vmware-}vcli/?pps");    # the ? makes sure that only existing paths will match.
use lib "$FindBin::RealBin/../lib";

$Util::script_version = "1.0";

use CGI ':standard';
use VMware::VIRuntime;
use XML::LibXML;
use AppUtil::XMLInputUtil;
use AppUtil::HostUtil;
use AppUtil::VMUtil;
use Data::Dumper;

use LML::Config;
my $C = new LML::Config();

# default paramter
my $xsd_file = "/usr/share/lab-manager-light/schema/vm-create.xsd";
my $xml_file = "";
my @vms;
my $linebreak = '\n';

# default values will be used in case we were called via webui
my $memory      = 2048;              # in MB
my $num_cpus    = 1;
my $guestid     = 'rhel6_64Guest';
my $disksize    = 16777216;          # in KB
my $nic_poweron = 1;
my %custom_fields;
my %networks;

# are we called via webui?
if (    param('name')
     && param('esx_host')
     && param('username')
     && param('expiration')
     && param('folder') )
{
    @vms = worker_array_from_post();

    # or do we have an xml source?
} else {
    # look if we got xml data over CGI
    if ( param('xml') ) {
        # write temporary file
        $xml_file = "/tmp/vm-create-data-" . time() . ".xml";
        open( TMP_XML, ">", $xml_file ) || die "Could not open '$xml_file' for writing" . $linebreak;
        flock( TMP_XML, 2 ) || die;
        print TMP_XML param('xml');
        close(TMP_XML);
    }

    @vms = worker_array_from_xml();
}

Util::connect();
create_vms(@vms);
Util::disconnect();

# Generate an array of vm to be created. Each vm is represented
# by a hash. The source of vm definitions is the given xml file.
# =============================================================
sub worker_array_from_xml {
    my @vms;

    # define command line options
    my %opts = (
                 filename => {
                               type     => "=s",
                               help     => "The location of the input xml file",
                               required => 0,
                               default  => $xml_file
                 },
                 schema => {
                             type     => "=s",
                             help     => "The location of the schema file",
                             required => 0,
                             default  => $xsd_file
                 }
    );

    # initialize vmware sdk
    Opts::add_options(%opts);
    Opts::parse();
    Opts::validate( \&validate );

    my $parser      = XML::LibXML->new();
    my $tree        = $parser->parse_file( Opts::get_option('filename') );
    my $root        = $tree->getDocumentElement;
    my @defined_vms = $root->findnodes('Virtual-Machine');

    foreach (@defined_vms) {
        # go through the section of Networks
        if ( $_->findvalue('Networks') ) {
            for my $entry ( $_->findnodes('Networks/Nic-Network') ) {
                $networks{ $entry->getAttribute('name') } = $entry->getAttribute('poweron');
            }
        }

        # go through the section of Custom-Values
        if ( $_->findvalue('Custom-Values') ) {
            for my $entry ( $_->findnodes('Custom-Values/Value') ) {
                $custom_fields{ $entry->getAttribute('name') } = $entry->textContent();
            }
        }

        # assemble the data hash for this vm
        my %vm = (
                   vmname        => $_->findvalue('Name'),
                   vmhost        => $_->findvalue('Host'),
                   datacenter    => $_->findvalue('Datacenter'),
                   guestid       => $_->findvalue('Guest-Id'),
                   datastore     => $_->findvalue('Datastore'),
                   disksize      => $_->findvalue('Disksize'),
                   memory        => $_->findvalue('Memory'),
                   num_cpus      => $_->findvalue('Number-of-Processor'),
                   nic_poweron   => $_->findvalue('Nic-Poweron'),
                   custom_fields => \%custom_fields,
                   target_folder => $_->findvalue('Target-Folder'),
                   vm_poweron    => $_->findvalue('VM-Poweron'),
                   networks      => \%networks
        );

        # add the vm hash to the worker array
        push( @vms, \%vm );
    }

    return @vms;
}

# Generate an array of the vm to be created. This
# vm is represented by a hash. The source of vm
# definition is the data from post and default values
# ===================================================
sub worker_array_from_post {
    my @vms;
    my $force_boot_target = "default";
    $force_boot_target = param('force_boot_target') if ( param('force_boot_target') );


    # initialize vmware sdk
    Opts::parse();

    # assemble custom fields hash
    %custom_fields = (
                       'Contact User ID'   => param('username'),
                       'Expires'           => param('expiration'),
                       'Force Boot'        => 'ON',
                       'Force Boot Target' => "$force_boot_target"
    );

    # set default networks hash
    my @default_vm_networks = ();
    my $config_default_vm_networks = $C->get( "vsphere", "default_vm_networks" );
    if ( $config_default_vm_networks ) {
        if ( ref($config_default_vm_networks) eq "ARRAY" ) {
            @default_vm_networks = @{$config_default_vm_networks};
        } else {
            @default_vm_networks = ($config_default_vm_networks);
        }
    }
    foreach ( @default_vm_networks ) {
        $networks{$_} = 1;
    }

    my $esx_host_fqdn = param('esx_host');
    $esx_host_fqdn =~ /(^[^\.]+).*$/;
    my $esx_host_name = $1;

    @vms = (
             {
               vmname        => param('name'),
               vmhost        => param('esx_host'),
               datacenter    => $C->get( "vsphere", "default_vm_datacenter" ),
               guestid       => $guestid,
               datastore     => $esx_host_name . ':datastore1',
               disksize      => $disksize,
               memory        => $memory,
               num_cpus      => $num_cpus,
               nic_poweron   => $nic_poweron,
               custom_fields => \%custom_fields,
               target_folder => param('folder'),
               vm_poweron    => 1,
               networks      => \%networks
             }
    );
    return @vms;
}

# compose error output related to the execution context
# =====================================================
sub error {
    my $message = shift;

    # print html header before anything else if CGI is used
    if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '500 Error while processing' );
        print "NEW_VM_STATUS=\"" . $message . "\"";
    } else {
        print "NEW_VM_STATUS=\"" . $message . "\"\n";
    }

    Util::disconnect();
    exit 1;
}

# compose a success output
sub success {
    my $uuid    = shift;
    my $message = shift;

    # print html header before anything else if CGI is used
    if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '200 vm created' );
    }
    print $uuid;
}

# This subroutine parses the input xml file to retrieve all the
# parameters specified in the file and passes these parameters
# to create_vm subroutine to create a single virtual machine
# =============================================================
sub create_vms {
    my @vms = @_;

    foreach (@vms) {
        create_vm(
                   vmname        => $_->{'vmname'},
                   vmhost        => $_->{'vmhost'},
                   datacenter    => $_->{'datacenter'},
                   guestid       => $_->{'guestid'},
                   datastore     => $_->{'datastore'},
                   disksize      => $_->{'disksize'},
                   memory        => $_->{'memory'},
                   num_cpus      => $_->{'num_cpus'},
                   nic_poweron   => $_->{'nic_poweron'},
                   custom_fields => $_->{'custom_fields'},
                   target_folder => $_->{'target_folder'},
                   vm_poweron    => $_->{'vm_poweron'},
                   networks      => $_->{'networks'}
        );
    }
}

# create a virtual machine
# ========================
sub create_vm {
    my %args = @_;
    my @vm_devices;
    my $host_view = Vim::find_entity_view( view_type => 'HostSystem',
                                           filter    => { 'name' => $args{vmhost} } );

    if ( !$host_view ) {
        error( "ERROR: " . "Host '$args{vmhost}' not found" );
    }

    my %ds_info = HostUtils::get_datastore(
                                            host_view => $host_view,
                                            datastore => $args{datastore},
                                            disksize  => $args{disksize}
    );

    if ( $ds_info{mor} eq 0 ) {
        if ( $ds_info{name} eq 'datastore_error' ) {
            error( "ERROR: " . "Datastore $args{datastore} not available." );
        }
        if ( $ds_info{name} eq 'disksize_error' ) {
            error( "ERROR: The free space " . "available is less than the specified disksize." );
        }
    }

    my $ds_path                     = "[" . $ds_info{name} . "]";
    my $controller_vm_dev_conf_spec = create_conf_spec();
    my $disk_vm_dev_conf_spec       = create_virtual_disk( ds_path => $ds_path, disksize => $args{disksize} );

    # add all configured networks
    foreach my $network ( sort keys( %{ $args{networks} } ) ) {
        my %net_settings = get_network(
                                        network_name => $network,
                                        poweron      => ${ $args{networks} }{$network},
                                        host_view    => $host_view
        );

        # check for errors
        if ( $net_settings{'error'} eq 0 ) {
            push( @vm_devices, $net_settings{'network_conf'} );

        } elsif ( $net_settings{'error'} eq 1 ) {
            error( "ERROR: " . "Network '$args{nic_network}' not found" );
        }
    }

    push( @vm_devices, $controller_vm_dev_conf_spec );
    push( @vm_devices, $disk_vm_dev_conf_spec );

    my $files = VirtualMachineFileInfo->new(
                                             logDirectory      => undef,
                                             snapshotDirectory => undef,
                                             suspendDirectory  => undef,
                                             vmPathName        => $ds_path
    );

    my $vm_config_spec = VirtualMachineConfigSpec->new(
                                                        name         => $args{vmname},
                                                        memoryMB     => $args{memory},
                                                        files        => $files,
                                                        numCPUs      => $args{num_cpus},
                                                        guestId      => $args{guestid},
                                                        deviceChange => \@vm_devices
    );

    my $datacenter_views = Vim::find_entity_views( view_type => 'Datacenter',
                                                   filter    => { name => $args{datacenter} } );

    unless (@$datacenter_views) {
        error( "ERROR: " . "Datacenter '$args{datacenter}' not found" );
    }

    if ( $#{$datacenter_views} != 0 ) {
        error( "ERROR: " . "Datacenter '$args{datacenter}' not unique" );
    }

    my $datacenter           = shift @$datacenter_views;
    my $datacenter_vm_folder = Vim::get_view( mo_ref => $datacenter->vmFolder );
    my $comp_res_view        = Vim::get_view( mo_ref => $host_view->parent );

    # create the folder regardless its already there
    #create_folder( folder => $args{target_folder} );

    # get the wished folder
    my $target_folder_view;
    my @found = split( /\//, $args{target_folder} );
    # remove any empty lines
    @found = grep( /\S/, @found );
    get_folder(
                folder      => $datacenter_vm_folder,
                found       => \@found,
                target_view => \$target_folder_view
    );

    eval {
        $target_folder_view->CreateVM( config => $vm_config_spec,
                                       pool   => $comp_res_view->resourcePool );

    };

    if ($@) {
        if ( ref($@) eq 'SoapFault' ) {
            if ( ref( $@->detail ) eq 'PlatformConfigFault' ) {
                error( "ERROR: Invalid VM configuration: " . ${ $@->detail }{'text'} );
            } elsif ( ref( $@->detail ) eq 'InvalidDeviceSpec' ) {
                error( "ERROR: Invalid Device configuration: " . ${ $@->detail }{'property'} );
            } elsif ( ref( $@->detail ) eq 'DatacenterMismatch' ) {
                error("ERROR: DatacenterMismatch, the input arguments had entities that did not belong to the same datacenter");
            } elsif ( ref( $@->detail ) eq 'HostNotConnected' ) {
                error("ERROR: Unable to communicate with the remote host, since it is disconnected");
            } elsif ( ref( $@->detail ) eq 'InvalidState' ) {
                error("ERROR: The operation is not allowed in the current state");
            } elsif ( ref( $@->detail ) eq 'DuplicateName' ) {
                error("ERROR: Virtual machine already exists");
            } else {
                error( "ERROR: " . $@ );
            }
        } else {
            error( "ERROR: " . $@ );
        }
    }

    # set the custom fields with defined values
    set_custom_fields( vmname        => $args{vmname},
                       custom_fields => $args{custom_fields} );
    # get the view of the previously created vm
    my $vm_views = VMUtils::get_vms( 'VirtualMachine', $args{vmname} );
    my $vm_view = shift @{$vm_views};
    # finally switch on the virtual machine
    if ( $args{vm_poweron} ) {
        eval { $vm_view->PowerOnVM(); };
        # handle errors
        if ($@) {
            error("ERROR: Switch on");
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
        shift( @{$found} );
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

    # get view to service object
    my $customFieldsManager = Vim::get_view( mo_ref => Vim::get_service_content()->customFieldsManager );
    # only if there are fields defined
    if ( defined $customFieldsManager->{field} ) {
        my $fields = $customFieldsManager->{field};

        # get  view of the previous created vm
        my $vm = Vim::find_entity_view( view_type => 'VirtualMachine',
                                        filter    => { "config.name" => $args{vmname} } );

        # go through each custom field, which is defined globally
        my $key;
        foreach my $field (@$fields) {
            # go through each configured custom field (in input xml)
            foreach ( keys %{ $args{custom_fields} } ) {
                # if we are at the right field, use its key to modify the custom field in vm
                if ( $field->name eq $_ ) {
                    $customFieldsManager->SetField(
                                                    entity => $vm,
                                                    key    => $field->key,
                                                    value  => ${ $args{custom_fields} }{ $field->name }
                    );
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
                                                     sharedBus => VirtualSCSISharing->new('noSharing')
    );

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
                                                              operation     => VirtualDeviceConfigSpecOperation->new('add')
    );
    return $disk_vm_dev_conf_spec;
}

# get network configuration
# =========================
#print "DEBUG: ".Data::Dumper->Dump([%{$data}])."" . $linebreak;
sub get_network {
    my %args         = @_;
    my $network_name = $args{network_name};
    my $poweron      = $args{poweron};
    my $host_view    = $args{host_view};      #DEBUG0
    my $network      = undef;
    my $unit_num     = 1;                     # 1 since 0 is used by disk

    if ($network_name) {
        my $network_list = Vim::get_views( mo_ref_array => $host_view->network );

        foreach (@$network_list) {
            if ( $network_name eq $_->name ) {
                $network = $_;

                my $dvs_view = Vim::get_view( mo_ref => $network->config->distributedVirtualSwitch );

                my $backing_port = DistributedVirtualSwitchPortConnection->new( portgroupKey => $network->key,
                                                                                switchUuid   => $dvs_view->uuid );

                my $nic_backing_info = VirtualEthernetCardDistributedVirtualPortBackingInfo->new( port => $backing_port );

                my $vd_connect_info = VirtualDeviceConnectInfo->new(
                                                                     allowGuestControl => 1,
                                                                     connected         => 0,
                                                                     startConnected    => $poweron
                );

                my $nic = VirtualVmxnet3->new(
                                               backing     => $nic_backing_info,
                                               key         => 0,
                                               unitNumber  => $unit_num,
                                               addressType => 'generated',
                                               connectable => $vd_connect_info
                );

                my $nic_vm_dev_conf_spec = VirtualDeviceConfigSpec->new( device    => $nic,
                                                                         operation => VirtualDeviceConfigSpecOperation->new('add') );
                return ( error => 0, network_conf => $nic_vm_dev_conf_spec );
            }
        }
        if ( !defined($network) ) {
            # no network found
            return ( error => 1 );
        }
    }
    # default network will be used
    return ( error => 2 );
}

# check the XML file
# =====================
sub validate {
    my $valid = XMLValidation::validate_format( Opts::get_option('filename') );
    if ( $valid == 1 ) {
        $valid = XMLValidation::validate_schema( Opts::get_option('filename'), Opts::get_option('schema') );
        if ( $valid == 1 ) {
            $valid = check_missing_value();
        }
    }
    return $valid;
}

# check missing values of mandatory fields
# ========================================
sub check_missing_value {
    my $valid    = 1;
    my $filename = Opts::get_option('filename');
    my $parser   = XML::LibXML->new();
    my $tree     = $parser->parse_file($filename);
    my $root     = $tree->getDocumentElement;

    # defect 223162
    if ( $root->nodeName eq 'Virtual-Machines' ) {
        my @vms = $root->findnodes('Virtual-Machine');
        foreach (@vms) {
            if ( !$_->findvalue('Name') ) {
                error("ERROR: Error in '$filename': <Name> value missing in one of the VM specifications");
            }
            if ( !$_->findvalue('Host') ) {
                error("ERROR: Error in '$filename': <Host> value missing in one of the VM specifications");
            }
            if ( !$_->findvalue('Datacenter') ) {
                error("ERROR: Error in '$filename':\n<Datacenter> value missing in one of the VM specifications");
            }
        }
    } else {
        error("ERROR: Error in '$filename': Invalid root element");
    }
    return $valid;
}

# cleanup temporary generated files
END {
    # TODO: ATM we have only one file, so make use of the "global" variable
    unlink($xml_file) if ($xml_file);
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
       <VM-Poweron>1</VM-Poweron>
       <Host>esx01.domain.loc</Host>
       <Datacenter>SGI</Datacenter>
       <Guest-Id>rhel6_64Guest</Guest-Id>
       <Datastore>esx04:datastore1</Datastore>
       <Disksize>8388608</Disksize>
       <Memory>1024</Memory>
       <Number-of-Processor>1</Number-of-Processor>
       <Networks>
          <Nic-Network name="VM Network 1" poweron="1"/>
          <Nic-Network name="VM Network 2" poweron="1"/>
       </Networks>
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
