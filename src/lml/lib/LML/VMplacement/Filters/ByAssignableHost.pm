package LML::VMplacement::Filters::ByAssignableHost;

use strict;
use warnings;
use Carp;
use LML::Config;

sub new {
    my ( $class, $config ) = @_;

    croak( "1st argument must be an instance of LML::Config called at " . ( caller 0 )[3] ) unless ( ref($config) eq "LML::Config" );

    my $self = {
                 config              => $config,
                 vm_host_assignments => _parse_vm_host_assignments($config)    # does croak if something is missconfigured
    };

    bless( $self, $class );
    return $self;
}

sub host_can_vm {
    my ( $self, $host, $vm_res ) = @_;

    foreach my $vm_host_assignment (keys %{$self->{vm_host_assignments}}){
        my $vm_pattern=$self->{vm_host_assignments}->{$vm_host_assignment}->{vm_pattern};
        
        if ($vm_res->{name} =~ qr(^$vm_pattern$)){
             my $host_pattern=$self->{vm_host_assignments}->{$vm_host_assignment}->{host_pattern};
         
             if ($host->{name} =~ qr(^$host_pattern$)){
                 return 1;
             } else {
                 return 0;
             }
        }
    }

    return 1;  
}

sub get_name {
    return 'ByAssignableHost';
}

#######################################
# private methods
#######################################

sub _parse_vm_host_assignments {
    my ($config) = @_;
    my @vm_host_assignments = $config->get_array( 'hostrules', 'vm_host_assignment' );

    my %result = ();
    foreach my $vm_host_assignment (@vm_host_assignments) {
        my $vm_pattern = $config->get('hostrules', $vm_host_assignment . '.vm_pattern');
        my $host_pattern = $config->get('hostrules', $vm_host_assignment . '.host_pattern');
        croak( "config is not properly set for $vm_host_assignment.vm_pattern" . ( caller 0 )[3] ) unless ( defined($vm_pattern) );
        croak( "config is not properly set for $vm_host_assignment.host_pattern" . ( caller 0 )[3] ) unless ( defined($host_pattern) );
        $result{$vm_host_assignment} = {vm_pattern => $vm_pattern, host_pattern=>$host_pattern};
    }

    return \%result;
}

1;
