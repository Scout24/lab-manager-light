package TestTools::VMmanager;

use strict;
use warnings;

use TestTools::VmCreateOptions;
use TestTools::VMcreated;

use LWP::UserAgent;
use HTTP::Request;
use DateTime;

use TeamCity::Messages;

# Constructor
sub new {
    my ( $class, $vm_create_options ) = @_;

    my $self = {
                 vm_create_options => $vm_create_options,
                 already_deleted   => 0
    };

    bless( $self, $class );

    return $self;
}

# Creates a new vm
# Returns new TestTools::VMcreated instance or cause a teamcity fail
sub create_vm {
    my ($self) = @_;

    if ( $self->{already_deleted} ) {
        teamcity_build_failure("Wrong usage - the created VM must be deleted before create a new one");
        die;
    }

    my %create_options = %{$self->{vm_create_options}};
    # take only keys that have a non-default (0) value and that can be send to vmcreate.pl
    my @send_options = grep { $create_options{$_} } ("name","username","expiration","folder","force_boot_target","esx_host","force_network");
    my $vm_create_url_data = join("&",map { "$_=$create_options{$_}" } @send_options); # build url option=option_value for send_options
    teamcity_build_progress( "Creating " . $self->{vm_create_options}->{name} . " ($vm_create_url_data)");

    my $uuid = $self->_do_http_post_request( "http://" . $self->{vm_create_options}->{test_host} . "/lml/restricted/vm-create.pl", $vm_create_url_data );

    if ( $uuid =~ /ERROR: / or $uuid =~ /\s+/ ) {
        teamcity_build_failure("Could not retrieve UUID '$uuid' of new VM");
        die;
    }
    return new TestTools::VMcreated( $uuid, $self->{vm_create_options} );
}

# deletes the vm
sub delete_vm {
    my ($self) = @_;

    if ( $self->{already_deleted} ) {
        return;
    }
    else {
        teamcity_build_progress( "Deleting " . $self->{vm_create_options}->{name} );
        my $res = $self->_do_http_post_request( "http://" . $self->{vm_create_options}->{test_host} . "/lml/restricted/vm-control.pl", "action=destroy&hosts=" . $self->{vm_create_options}->{name} );
        if ( $res =~ /ERROR/ ) {
            teamcity_build_failure("Could not delete $res");
            die;
        }
        else {
            $self->{already_deleted} = 1;
        }
    }
}

#####################################################################
#####################################################################
# PRIVATE FUNCTIONS
#####################################################################
#####################################################################

sub _do_http_post_request {
    my ( $self, $url, $data ) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->agent("lml-system-test ");

    my $req = HTTP::Request->new( POST => "$url" );
    $req->content_type("application/x-www-form-urlencoded");
    $req->content("$data");

    my $res = $ua->request($req);
    return $res->is_success ? $res->content : "ERROR: " . $res->content;
}

1;
