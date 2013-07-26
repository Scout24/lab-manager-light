package LML::VMplacement;

use strict;
use warnings;
use Carp;

sub new {
    my ( $class, $lab, $filters, $rankers ) = @_;

    croak( "1st argument must be an instance of LML::Lab called at " . ( caller 0 )[3] ) unless ( ref($lab) eq "LML::Lab" );

    if ( defined($filters) ) {
        croak( "2nd argument must be an Array Ref called at " . ( caller 0 )[3] ) unless ( ref($filters) eq "ARRAY" );
        foreach (@$filters) {
            croak( "filter " . ( ref($_) ? ref($_) : $_ ) . " has no host_can_vm method called at " . ( caller 0 )[3] )
              unless ( $_->can("host_can_vm") );
        }
    }
    else {
        # todo set default filters
        $filters = [];
    }

    if ( defined($rankers) ) {
        croak( "3rd argument must be an Array Ref called at " . ( caller 0 )[3] ) unless ( ref($rankers) eq "ARRAY" );
        foreach (@$rankers) {
            croak( "ranker " . ( ref($_) ? ref($_) : $_ ) . " has no get_rank_value method called at " . ( caller 0 )[3] )
              unless ( $_->can("get_rank_value") );
        }
    }
    else {
        # todo set default rankers
        $rankers = [];
    }

    my $self = {
                 lab     => $lab,
                 filters => $filters,
                 rankers => $rankers,
    };

    bless( $self, $class );
    return $self;
}

sub get_recommendations {
    my ( $self, $vm_res ) = @_;
    croak( "1st arg must be LML::VMresources in " . ( caller 0 )[3] ) unless ( ref($vm_res) eq "LML::VMresources" );
    my @filtered_hosts = $self->_filter( $vm_res, $self->{lab}->get_hosts );
    my @ranked_hosts = $self->_rank(@filtered_hosts);
    return $self->_build_recommendations( $vm_res, @ranked_hosts );
}

sub _filter {
    my ( $self, $vm_res, @hosts ) = @_;
    return grep { $self->_check_by_filters( $vm_res, $_ ) } @hosts;
}

sub _check_by_filters {
    my ( $self, $vm_res, $host ) = @_;
    foreach my $filter ( @{ $self->{filters} } ) {
        return 0 unless ( $filter->host_can_vm( $host, $vm_res ) );
    }
    return 1;
}

sub _build_recommendations {
    my ( $self, $vm_res, @hosts ) = @_;
    return map { $self->_map_vm_res_on_host( $vm_res, $_ ) } @hosts;
}

sub _map_vm_res_on_host {
    my ( $self, $vm_res, $host ) = @_;
    #TODO: Map vm_res disk wishes onto host
    my $rec = {
        id => $host->{id},
        # most simple disk->datastore mapping,
        # return 1st host datastore for each vm disk
        datastores => [ map { $host->{datastores}[0] } @{ $vm_res->{disks} } ],
    };
    return $rec;
}

sub _rank {
    my ( $self, @hosts ) = @_;
    return sort { $self->_collect_ranks($a) <=> $self->_collect_ranks($b) } @hosts;
}

sub _collect_ranks {
    my ( $self, $host ) = @_;
    my $rank = 0;
    foreach my $ranker ( @{ $self->{rankers} } ) {
        $rank += $ranker->get_rank_value($host);
    }
    return $rank;
}

1;
