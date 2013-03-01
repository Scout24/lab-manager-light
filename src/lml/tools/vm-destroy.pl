#!/usr/bin/perl -w

# Purpose: Deletes an single VM identified by the uuid. The machine will be powered off if still on
#          and then the machine will be completely deleted including the files in datastore
#
# Authors:  
#     Stefan Neben <stefan.neben@gmail.com>
#

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;

$Util::script_version = "1.0";

my %opts = (
    uuid => {
        type     => "=s",
        help     => "The uuid of the vm to be destroyed",
        required => 1
    }
);

Opts::add_options(%opts);
Opts::parse();

# connect to api
Util::connect();

# initialize needed variables
my $uuid;

# get the uuid
if ( Opts::get_option('uuid') ) {
    $uuid = Opts::get_option('uuid');

} else {
    Util::trace( 0, "The uuid of the vm is not defined, quit ...\n" );
    exit 1
}

# get the view of the vm to be deleted
my $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine',
                                     filter    => { 'config.uuid' => $uuid } );

# check the success
if ( not defined $vm_view ) {
    Util::trace( 0, "Unable to get view for wished uuid, exit ...\n" );
    exit 1;
}

# switch off the vm
poweroff_vm( view => $vm_view );

# finally destroy the vm
destroy_vm( view => $vm_view );

# disconnect from api
Util::disconnect();

sub destroy_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # destroy the vm
    eval {
        $vm_view->Destroy();
        Util::trace( 0, "Successfully destroyed virtual machine with uuid: "
                     . $vm_view->config->uuid . "\n" );
    };

    # check the success
    if ( $@ ) {
        Util::trace( 0, "Error destroying VM: " . ref($@->detail) . "\n" );
    }
}

sub poweroff_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # poweroff the vm
    eval {
        $vm_view->PowerOffVM();
        Util::trace( 0, "Successfully switched off VM with uuid: "
                      . $vm_view->config->uuid . "\n" );
    };

    # check the success
    if ( $@ ) {
        Util::trace( 0, "Error destroying VM: "
                      . ref($@->detail) . "\n" );
    }
}
