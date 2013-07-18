package TestTools::VMmanager;

use strict;
use warnings;

use TestTools::VmCreateOptions;
use TestTools::VMcreated;

use LWP::UserAgent;
use HTTP::Request;
use DateTime;

# Constructor
sub new {
    my ($class) = @_;

    my $self = {
                 vm_create_options => new TestTools::VmCreateOptions(),
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
        print "##teamcity[buildStatus status='FAILURE' text='Wrong usage - the created VM must be deleted before create a new one']\n";
        exit 1;
    }

    $self->_report_progress( "Creating " . $self->{vm_create_options}->{vm_host} );

    my $uuid = $self->_do_http_post_request( "http://" . $self->{vm_create_options}->{test_host} . "/lml/restricted/vm-create.pl", "name=" . $self->{vm_create_options}->{vm_host} . "&esx_host=" . $self->{vm_create_options}->{esx_host} . "&username=" . $self->{vm_create_options}->{username} . "&expiration=" . $self->{vm_create_options}->{expiration_date} . "&folder=" . $self->{vm_create_options}->{folder} . "&force_boot_target=" . $self->{vm_create_options}->{force_boot_target} );

    
    if ( $uuid =~ /ERROR: / or $uuid =~ /\s+/ ) {
        print "##teamcity[buildStatus status='FAILURE' text='Could not retrieve uuid " . $uuid . "']\n";
        exit 1;
    }
    return new TestTools::VMcreated( $uuid, $self->{vm_create_options} );
}

# deletes the vm
sub delete_vm {
    my ($self) = @_;

    if ( $self->{already_deleted} ) {
        return;
    } else {
        $self->_report_progress( "Deleting " . $self->{vm_create_options}->{vm_host} );
        my $res = $self->_do_http_post_request( "http://" . $self->{vm_create_options}->{test_host} . "/lml/restricted/vm-control.pl", "action=destroy&hosts=" . $self->{vm_create_options}->{vm_host} );
        if ( $res =~ /ERROR/ ) {
            print "##teamcity[buildStatus status='FAILURE' text='Could not delete " . $res . "']\n";
            exit 1;
        } else {
            $self->{already_deleted} = 1;
        }
    }
}

#####################################################################
#####################################################################
# PRIVATE FUNCTIONS
#####################################################################
#####################################################################

sub _report_progress {
    my ( $self, $message ) = @_;

    print "##teamcity[progressMessage '$message']" . $/;
}

sub _do_http_post_request {
    my ( $self, $url, $data ) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->agent("TeamCity/0.1 ");

    my $req = HTTP::Request->new( POST => "$url" );
    $req->content_type("application/x-www-form-urlencoded");
    $req->content("$data");

    my $res = $ua->request($req);
    return $res->is_success ? $res->content : "ERROR: " . $res->status_line;
}

1;
