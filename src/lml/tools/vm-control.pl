#!/usr/bin/perl -w

# Purpose: Deletes an single VM identified by the uuid. The machine will be powered off if still on
#          and then the machine will be completely deleted including the files in datastore
#
# Authors:  
#     Stefan Neben <stefan.neben@gmail.com>

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use LML::Common;
use LML::Config;
use LML::VMware;

$Util::script_version = "1.0";

# define own options over the vmware api
my %opts = (
    reinstall => {
        type     => "",
        help     => "The action to be executed for the given vm",
        required => 0
    },
    destroy => {
        type     => "",
        help     => "The name of the vm to be destroyed",
        required => 0
    }
);

# parse the options through vmware api
Opts::add_options(%opts);
Opts::parse();

# get the lml configuration
my $C = new LML::Config();

# connect to VMware
print( "Connecting to VI" . "\n" );
connect_vi();

# get the vm name
my $vm_name;
if ( @ARGV ) {
    # check the command option consistence
    if ( Opts::get_option('reinstall') && Opts::get_option('destroy')) {
        Util::trace( 0, "The option --reinstall and --destroy can not be used at the same time, quit ...\n" );
        exit 1
    }
    # save the delivered hostname
    $vm_name = $ARGV[0];

# if no vm name is given
} else {
    Util::trace( 0, "The name of the vm is not defined, quit ...\n" );
    exit 1
}

# get the view of the vm to work with
my $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine',
                                     filter    => { 'name' => $vm_name } );

# check the success
if ( not defined $vm_view ) {
    Util::trace( 0, "Unable to get view for wished vm, quit ...\n" );
    exit 1;
}

# print out which vm is used
Util::trace( 0, "Using VM " . $vm_view->config->name . " (" . $vm_view->config->uuid . ") ...\n" );

if ( Opts::get_option('reinstall') ) {
    # set the forceboot value to ON
    set_forceboot( view => $vm_view );
    # reboot the vm
    reboot_vm( view => $vm_view );

} elsif ( Opts::get_option('destroy') ) {
    # switch off the vm
    poweroff_vm( view => $vm_view );
    # finally destroy the vm
    destroy_vm( view => $vm_view );

# or no supported action is defined
} else {
    Util::trace( 0, "No option --reinstall or --destroy is given! Exit...\n" );
    exit 1;
}

sub destroy_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # destroy the vm
    eval {
        $vm_view->Destroy();
    };

    # check the success
    if ( $@ ) {
        Util::trace( 0, "Error destroying VM: " . ref($@->detail) . "\n" );
    } else {
        Util::trace( 0, "Successfully destroyed virtual machine\n" );
    }
}

sub poweroff_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # poweroff the vm
    eval {
        $vm_view->PowerOffVM();
    };

    # check the success
    if ( $@ ) {
        Util::trace( 0, "Error destroying VM: "
                      . ref($@->detail) . "\n" );
    } else {
        Util::trace( 0, "Successfully switched off VM \n" );
    }
}

sub reboot_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # reboot the vm
    eval {
        $vm_view->RebootGuest();
    };

    # check the success
    if ( $@ ) {
        Util::trace( 0, "Error rebooting VM: "
                      . ref($@->detail) . "\n" );
    } else {
        Util::trace( 0, "Successfully triggered reboot of VM \n" );
    }
}

sub set_forceboot {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # get view to service object for the custm field manager
    my $customFieldsManager =
        Vim::get_view( mo_ref => Vim::get_service_content()->customFieldsManager );

    # only if there are fields defined
    if (defined $customFieldsManager->{field}) {
        my $fields = $customFieldsManager->{field};

        foreach my $field ( @$fields ) {
            if( $field->name eq $C->get("vsphere", "forceboot_field") ) {
                eval {
                    $customFieldsManager->SetField( entity => $vm_view,
                                                    key    => $field->key,
                                                    value  => "ON" );
                };
                # check the success
                if ( $@ ) {
                    Util::trace( 0, "Error setting forceboot: "
                                  . ref($@->detail) . "\n" );
                } else {
                    Util::trace( 0, "Successfully set forceboot to ON\n" );
                }
            }
        }
    }
}
