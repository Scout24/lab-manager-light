#
# vmware functions go here
#

package LML::VMware;

use strict;
use Exporter;
use vars qw(
            $VERSION
            @ISA
            @EXPORT
           );
our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT   	= qw(connect_vi search_vm custom_fields setVmExtraOptsU setVmExtraOptsM);
					
use VMware::VIRuntime;


# only on VMA
#use VMware::VmaTargetLib;


our %VM=(); # empty hash for VMs
our $find_tag = "";
our $custom_field_id=0; # ID of custom field to use

our %CUSTOMFIELDIDS; # internal cache for custom field id->name relation

# disconnect at the end, no matter what
$SIG{__DIE__} = sub{Util::disconnect()};
$Util::script_version = "1.0";

our %opts = (
	tag => {
		type => ":s",
		default => "easyVCB",
		variable => "VI_TAG",
		help => "Find only VMs with specified tag",
		required => 0,
	},
);


################################ sub #################
##
## getcustomvalue (<vm>)
##
## retrieve the value of the custom field specified in the global $custom_field_id
##
##
sub getcustomvalue {
	my $vm = shift;

	return undef unless ($custom_field_id and $vm->customValue); # do nothing if the field is not defined
	# iterate over the customValues

	foreach my $value (@{$vm->customValue}) {
		if ($value->key eq $custom_field_id){
			return $value->value;
		}
	}
	return undef;
}


################################ sub #################
##
## handle_vm (<vm>)
##
## do something with a vm that was found
##
## at the moment, add the vm to the @RESULT array
##
##
sub handle_vm ($) {
	my $vm = shift;
	# filter out templates
	return undef if ($vm->config->template);	
	# filter out only tagged VM
	if ($custom_field_id) {
		# find out custom value, if needed
		my $customvalue=getcustomvalue($vm);
		Util::trace(1,"  Custom Value[$find_tag]: $customvalue\n") if ($customvalue) ;
		return undef unless ($customvalue);
		return undef unless ($customvalue eq "1" or 
						$customvalue eq "true" or
						$customvalue eq "yes");
	}
#	print Dumper([$vm]);
	my $uuid = $vm->config->uuid;
	$VM{$uuid} = {
			"NAME" => $vm->name,
			"PATH" => Util::get_inventory_path($vm,$vm->{vim}),
			"UUID" => $uuid,
#			"DEVICES" => $vm->config->hardware,
		};
	foreach my $vm_dev (@{$vm->config->hardware->device}) {
		if ($vm_dev->can("macAddress") and defined($vm_dev->macAddress)) {
			$VM{$uuid}{"MAC"}{$vm_dev->macAddress} = $vm_dev->backing->deviceName;
#			print "MAC: ".$vm_dev->macAddress."\n";
		}
	}
	if ($vm->customValue) {
		foreach my $value (@{$vm->customValue}) {
			$VM{$uuid}{"CUSTOMFIELDS"}{$CUSTOMFIELDIDS{$value->key}}=$value->value;
		}
	}
# keep entire VM object
# don't need it at the moment
#	$VM{$uuid}{OBJECT}=$vm;
	# store relevant extraConfig
	for my $extraConfig (@{$vm->config->extraConfig}) {
		$VM{$uuid}{EXTRAOPTIONS}{$extraConfig->key} = $extraConfig->value if ($extraConfig->key eq "bios.bootDeviceClasses");
	}
	$VM{$uuid}{MO_REF}=$vm->{mo_ref};
	return($vm->name);
}

################################ sub #################
##
## walk_mob (<object>)
##
## walk down the managed object browser searching for VM and call
## handle_vm for each VM found
##
##
sub walk_mob {
	my $object = shift;
	Util::trace(1,"Examining '".$object->name."' [".Util::get_inventory_path($object,$object->{vim})."]\n");
	# walk the children recursively
	if ($object->can("childEntity")) {
		# walk in only if there are any children
		if ($object->childEntity) {
			foreach my $child (@{$object->childEntity}) {
				walk_mob(Vim::get_view(mo_ref=>$child));
			}
		}
	}
	# walk into vmFolder (there is always only 1 vmFolder in each Datacenter
	if ($object->can("vmFolder")) {
		walk_mob(Vim::get_view(mo_ref=>$object->vmFolder));
	}
	# if this is an VM, handle it
	if ($object->can("config") and defined($object->config)) {
		if ($object->config->can("uuid")) {
			# this seems to be a VM
			handle_vm($object);
		}
	}	
}


################################ sub #################
##
## connect_vi
##
##
##

sub connect_vi() {
	Opts::add_options(%opts);
	Opts::parse();

# TODO: the validate call seems to query for VI credentials
#	even though they are not required on VMA
#	fix so that it won't do that anymore
	eval { Opts::validate(); };
	die("Could not validate VI options: $@") if ($@);

#	eval { 
#		my @targets = VmaTargetLib::enumerate_targets;
#		# TODO: walk through all available VI systems, not only the first one
#		$targets[0]->login() 
#	};
	eval { Util::connect(); };
	die("Could not connect to VI: $@") if ($@);

	# initialize CUSTOMFIELDIDS and retrieve custom fields
	my %fields = custom_fields();
	
	# find out about using a custom field definition
	if (Opts::option_is_set('tag')) {
		$find_tag = Opts::get_option('tag');
		$find_tag = "easyVCB" unless ($find_tag); # set reasonable default
		Util::trace(1, "Will find only '$find_tag' tagged VM\n");

		if (exists($fields{$find_tag})) {
			$custom_field_id = $fields{$find_tag};
		} else {
			die "Could not find custom field ID for '$find_tag'";
		}
	}
}

################################ sub #################
##
## custom_fields
##
## returns a hash of name->id pairs of defined custom fields
##
sub custom_fields {
	%CUSTOMFIELDIDS=(); # reset custom field ID cache
	my %CUSTOMFIELDS=(); # empty hash for custom fields
	my $custom_fields_manager = Vim::get_view(
		mo_ref => Vim::get_service_content->customFieldsManager
	);
	# iterate over custom field definitions and build hash array with name->ID mappings
	foreach my $field (@{$custom_fields_manager->field}){
		Util::trace(2,"Field ID '".$field->key."' => '".$field->name."'\n");
		$CUSTOMFIELDS{$field->name} = $field->key;
		$CUSTOMFIELDIDS{$field->key} = $field->name;
	}
	return %CUSTOMFIELDS;
}

################################ sub #################
##
## search_vm (<list of paths>)
##
##
##
sub search_vm {
	# collect the virtual machines to work on in @VM
	if (@_) {
		foreach my $path (@_) {
			my $searchindex = Vim::get_view(mo_ref=>Vim::get_service_content->searchIndex);
			my $searchresult = $searchindex->FindByInventoryPath(inventoryPath => $path);
			if ($searchresult) {
				walk_mob(Vim::get_view(mo_ref => $searchresult));
			} else {
				die "ERROR: Could not find inventory path '$path'";
			}
		}
	} else {
	# method 3: walk down from the very top
		walk_mob(Vim::get_view(mo_ref=>Vim::get_service_content->rootFolder));
	}

	# print results
	if ($Util::tracelevel > 1) {
		foreach my $uuid (keys(%VM)) {
			print("VM=$uuid\n");
			foreach my $key (keys(%{ $VM{$uuid} } )) {
				print("\t$key = $VM{$uuid}{$key}\n");
			}
		}
	}
	
	return(%VM);
}


############################### sub #################
##
## setVmExtraOptsU (<uuid of VM>,<option key>,<option value>)
##
##
sub setVmExtraOptsU {
	my $uuid = shift;
	my $key = shift;
	my $value = shift;
	eval {
		my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine',
                                                 filter => {uuid => $uuid});
		if($vm_view) {   
			my $vm_config_spec = VirtualMachineConfigSpec->new(
                                                  extraConfig => [OptionValue->new( key => $key, value => $value ),] );
			$vm_view->ReconfigVM( spec => $vm_config_spec );
		}
	};
	if ($@) {
		Util::trace(0, "\nReconfiguration failed: ");
		if (ref($@) eq 'SoapFault') {
			if (ref($@->detail) eq 'TooManyDevices') {
				Util::trace(0, "\nNumber of virtual devices exceeds "
					. "the maximum for a given controller.\n");
			}
			elsif (ref($@->detail) eq 'InvalidDeviceSpec') {
				Util::trace(0, "The Device configuration is not valid\n");
				Util::trace(0, "\nFollowing is the detailed error: \n\n$@");
			}
			elsif (ref($@->detail) eq 'FileAlreadyExists') {
				Util::trace(0, "\nOperation failed because file already exists");
			}
			else {
				Util::trace(0, "\n" . $@ . "\n");
			}
		} else {
			Util::trace(0, "\n" . $@ . "\n");
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
	my $key = shift;
	my $value = shift;
	eval {
		my $vm_view = Vim::get_view(mo_ref=>$mo_ref);
		if($vm_view) {   
			my $vm_config_spec = VirtualMachineConfigSpec->new(
                                                  extraConfig => [OptionValue->new( key => $key, value => $value ),] );
			$vm_view->ReconfigVM( spec => $vm_config_spec );
		}
	};
	if ($@) {
		Util::trace(0, "\nReconfiguration failed: ");
		if (ref($@) eq 'SoapFault') {
			if (ref($@->detail) eq 'TooManyDevices') {
				Util::trace(0, "\nNumber of virtual devices exceeds "
					. "the maximum for a given controller.\n");
			}
			elsif (ref($@->detail) eq 'InvalidDeviceSpec') {
				Util::trace(0, "The Device configuration is not valid\n");
				Util::trace(0, "\nFollowing is the detailed error: \n\n$@");
			}
			elsif (ref($@->detail) eq 'FileAlreadyExists') {
				Util::trace(0, "\nOperation failed because file already exists");
			}
			else {
				Util::trace(0, "\n" . $@ . "\n");
			}
		} else {
			Util::trace(0, "\n" . $@ . "\n");
		}
	}
}
1;
