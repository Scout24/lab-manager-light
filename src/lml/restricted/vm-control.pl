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

use CGI ':standard';
use JSON;

use LML::Common;
use LML::Config;
use LML::VMware;

$Util::script_version = "1.0";

# initialization
my $header_sent = 0;
my $action;
my @VMS;
my @processed_hosts;

# get the lml configuration
my $C = new LML::Config();

# are we in CGI context?
if ( param('action') ) {
    # get the action
    $action = param('action');

    # assemble hosts array if existent
    if (param('hosts')) {
        @VMS = param('hosts');
    } else {
            print header( -status => '500 Nothing to do' );
            print "No hosts were selected";
            exit 0;
    }

    # ok commandline context
} else {
    # define own options over the vmware api
    my %opts = (
                 detonate => {
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

    # get the vm name
    if (@ARGV) {
        # check the command option consistence
        if ( Opts::get_option('detonate') && Opts::get_option('destroy') ) {
            error("The option --reinstall and --destroy can not be used at the same time, quit ...");
        }

        # save the delivered action
        if ( Opts::get_option('detonate') ) {
            $action = 'detonate';
        } elsif ( Opts::get_option('destroy') ) {
            $action = 'destroy';
        } else {
            error("No option --reinstall or --destroy is given! Exit...");
        }

        # save the delivered hostname(s)
        foreach (@ARGV) {
            push( @VMS, $_ );
        }

        # if no vm name is given
    } else {
        error("The name of the vm is not defined, quit ...");
    }
}

# connect to VMware
connect_vi();

foreach my $vm_name (@VMS) {
    # get the view of the vm to work with
    my $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine',
                                         filter    => { 'name' => $vm_name } );

    # check the success
    if ( not defined $vm_view ) {
        error("Unable to get view for vm \"$vm_name\", quit ...");
    }

    if ( $action eq "detonate" ) {
        # set the forceboot value to ON
        set_forceboot( name => $vm_name,
                       view => $vm_view );
        # reboot the vm
        reboot_vm( name => $vm_name,
                   view => $vm_view );
        # add the processed machine to the processed array
        push(@processed_hosts, $vm_name);

    } elsif ( $action = 'destroy' ) {
        # switch off the vm
        poweroff_vm( name => $vm_name,
                     view => $vm_view );
        # finally destroy the vm
        destroy_vm( name => $vm_name,
                    view => $vm_view );
        # add the processed machine to the processed array
        push(@processed_hosts, $vm_name);
    }
}

# print an HTML success header if we are in CGI context
if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '200 vm created' );
}

# print out json formatted array
print encode_json(\@processed_hosts) . "\n";

# compose a error output
sub error {
    my $message   = shift;
    my $linebreak = "\n";

    # print html header before anything else if CGI is used
    if ( exists $ENV{GATEWAY_INTERFACE} ) {
        print header( -status => '500 Error while processing' );
        $linebreak = "<br>";
    }

    print $message. $linebreak;

    Util::disconnect();
    exit 1;
}

sub destroy_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # destroy the vm
    eval { $vm_view->Destroy(); };

    # check the success
    if ($@) {
        error( "Error destroying VM: " . ref( $@->detail ) );
    }
}

sub poweroff_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # poweroff the vm
    eval { $vm_view->PowerOffVM(); };

    # check the success
    if ($@) {
        error( "Error destroying VM: " . ref( $@->detail ) );
    }
}

sub reboot_vm {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # reboot the vm
    eval { $vm_view->RebootGuest(); };

    # check the success
    if ($@) {
        error( "Error rebooting VM: " . ref( $@->detail ) );
    }
}

sub set_forceboot {
    my %args = @_;

    # get vm view
    my $vm_view = $args{view};

    # get view to service object for the custm field manager
    my $customFieldsManager = Vim::get_view( mo_ref => Vim::get_service_content()->customFieldsManager );

    # only if there are fields defined
    if ( defined $customFieldsManager->{field} ) {
        my $fields = $customFieldsManager->{field};

        foreach my $field (@$fields) {
            if ( $field->name eq $C->get( "vsphere", "forceboot_field" ) ) {
                eval { $customFieldsManager->SetField( entity => $vm_view, key => $field->key, value => "ON" ); };
                # check the success
                if ($@) {
                    error( "Error setting forceboot: " . ref( $@->detail ) );
                }
            }
        }
    }
}
