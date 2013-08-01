package LML::VMplacement;

use strict;
use warnings;
use Carp;
use LML::VMplacement::Filters::ByOverallStatus;
use LML::VMplacement::Filters::ByMemory;
use LML::VMplacement::Filters::ByNetworkLabel;
use LML::VMplacement::Filters::ByGroupReliability;

use LML::VMplacement::Rankers::ByOverallStatus;
use LML::VMplacement::Rankers::ByCpuUsage;
use LML::VMplacement::Rankers::ByMemory;
use LML::Common;
use Text::TabularDisplay;

sub new {
    my ( $class, $config, $lab, $filters, $rankers ) = @_;

    croak( "1st argument must be an instance of LML::Config called at " . ( caller 0 )[3] ) unless ( ref($config) eq "LML::Config" );

    croak( "2nd argument must be an instance of LML::Lab called at " . ( caller 0 )[3] ) unless ( ref($lab) eq "LML::Lab" );

    if ( defined($filters) ) {
        croak( "3rd argument must be an Array Ref called at " . ( caller 0 )[3] ) unless ( ref($filters) eq "ARRAY" );
        foreach (@$filters) {
            croak( "filter " . ( ref($_) ? ref($_) : $_ ) . " has no host_can_vm or get_name method called at " . ( caller 0 )[3] )
              unless ( $_->can("host_can_vm") && $_->can("get_name") );
        }
    }
    else {
        # todo set default filters
        $filters = [
            new LML::VMplacement::Filters::ByOverallStatus,         #
            new LML::VMplacement::Filters::ByMemory,                #
            new LML::VMplacement::Filters::ByNetworkLabel($lab),    #
            new LML::VMplacement::Filters::ByGroupReliability( $lab, $config )    #
        ];
    }

    if ( defined($rankers) ) {
        croak( "4th argument must be an Array Ref called at " . ( caller 0 )[3] ) unless ( ref($rankers) eq "ARRAY" );
        foreach (@$rankers) {
            croak( "ranker " . ( ref($_) ? ref($_) : $_ ) . " has no get_rank_value or get_name method called at " . ( caller 0 )[3] )
              unless ( $_->can("get_rank_value") && $_->can("get_name") );
        }
    }
    else {
        # todo set default rankers
        $rankers = [
                     new LML::VMplacement::Rankers::ByOverallStatus,    #
                     new LML::VMplacement::Rankers::ByCpuUsage,         #
                     new LML::VMplacement::Rankers::ByMemory
        ];
    }

    my $self = {
                 config  => $config,
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
    my $debug_infos = {};

    foreach my $filter ( @{ $self->{filters} } ) {
        ${$debug_infos}{ $filter->get_name() } = [];
    }
    my @filtered_hosts = grep { $self->_check_by_filters( $vm_res, $debug_infos ,$_) } @hosts;

    if ($isDebug) {
        $self->_pretty_print_filtering($debug_infos,$vm_res->{name});
    }

    return @filtered_hosts;
}

sub _check_by_filters {
    my ( $self, $vm_res, $debug_infos, $host ) = @_;
    foreach my $filter ( @{ $self->{filters} } ) {
        unless ( $filter->host_can_vm( $host, $vm_res ) ) {
            push @{${$debug_infos}{ $filter->get_name() }}, $host->{name};
            return 0;
        }
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

    if ($isDebug) {
        $self->_pretty_print_ranking(@hosts);
    }

    return sort { $self->_collect_ranks($b) <=> $self->_collect_ranks($a) } @hosts;
}

sub _collect_ranks {
    my ( $self, $host ) = @_;
    my $rank = 0;
    foreach my $ranker ( @{ $self->{rankers} } ) {
        $rank += $ranker->get_rank_value($host);
    }
    return $rank;
}

sub _pretty_print_filtering {
    my ( $self, $debug_infos, $vm_name ) = @_;

    my @columns = ();
    foreach my $filter ( @{ $self->{filters} } ) {
        push @columns, $filter->get_name();
    }

    my $t = Text::TabularDisplay->new;
    $t->columns(@columns);

    my $has_something_to_debug = 1;

    while ($has_something_to_debug) {

        $has_something_to_debug = 0;
        my @row = ();

        foreach my $filter ( @{ $self->{filters} } ) {
            my $filtered_host = shift( @{ $debug_infos->{ $filter->get_name() } } );

            push @row, defined($filtered_host) ? $filtered_host : '';
            $has_something_to_debug = 1 if defined($filtered_host);
        }
        $t->add(@row) if $has_something_to_debug;
    }
    Debug( "Apply auto placement for vm $vm_name:\nFiltering of suitable esx hosts (the filter order is like the column order):\n" . $t->render );
}

sub _pretty_print_ranking {
    my ( $self, @hosts ) = @_;

    my @columns = ("Host-ID");
    foreach my $ranker ( @{ $self->{rankers} } ) {
        push @columns, $ranker->get_name();
    }
    push @columns, 'Ranking';

    my $t = Text::TabularDisplay->new;
    $t->columns(@columns);

    foreach my $host (@hosts) {
        my @row  = ( $host->{name} );
        my $rank = 0;
        foreach my $ranker ( @{ $self->{rankers} } ) {
            my $current_rank_value = $ranker->get_rank_value($host);
            push @row, $current_rank_value;
            $rank += $current_rank_value;
        }
        push @row, $rank;
        $t->add(@row);
    }

    Debug( "Ranking of suitable esx hosts (the host with the highest Ranking will be choosen):\n" . $t->render );
}

1;
