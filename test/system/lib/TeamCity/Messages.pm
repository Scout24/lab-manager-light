package TeamCity::Messages;

use utf8;
use strict;
use warnings;

use Exporter;
use vars qw(
  @ISA
  @EXPORT
);
our @ISA    = qw(Exporter);
our @EXPORT = qw(teamcity_build_status teamcity_build_failure teamcity_build_success teamcity_build_progress);

use Carp;

use TeamCity::BuildMessages ':all';

sub teamcity_build_status {
    my ( $status, $message ) = @_;
    teamcity_emit_build_message(
                                 "buildStatus",
                                 status => ( defined $status and $status ) ? "SUCCESS" : "FAILURE",
                                 text => $message
    );
}

sub teamcity_build_failure {
    my ($message) = @_;
    teamcity_build_status( undef, $message );
}

sub teamcity_build_success {
    my ($message) = @_;
    teamcity_build_status( 1, $message );
}

sub teamcity_build_progress {
    my ($message) = @_;
    teamcity_emit_build_message( "buildProgress", text => $message );
}

1;
