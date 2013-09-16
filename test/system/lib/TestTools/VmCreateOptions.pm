package TestTools::VmCreateOptions;

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use DateTime;
use Carp;
use TeamCity::Messages;

sub new {
    my ( $class, $self ) = @_;
    croak("Arg must be hashref of vm options") unless ( ref($self) eq "HASH" );
    # extend test data with builtins
    $self->{expiration} = DateTime->today()->add( days => 1 )->dmy(".");
    $self->{force_boot_target} = 'qrdata' unless ($self->{force_boot_target});
    $self->{name} = sprintf "%s%02d", $self->{vm_name_prefix}, (localtime)[1] + 1; # current minute plus 1 yields VMs starting frmo 01

    # make sure that everything is set
    if (
         not(     $self->{test_host}
              and $self->{vm_name_prefix}
              and $self->{username}
              and $self->{folder}
              and $self->{lmlhostpattern} )
      )
    {
        teamcity_build_failure("Cannot create VM - not all requires options specified");
        croak "Need to provide at least test_host, vm_name_prefix, username, folder and lmlhostpattern options.";
    }

    bless $self, $class;

    return $self;
}

1;
