#!/usr/bin/perl

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::VMware;
use LML::Validation qw/validate_with $VALIDATE_INTEGER/;
use Data::Dumper;
use Date::Parse;
use DateTime;
use JSON;

#
# NOTE: The following two lines are the only thing that ties this script to LML.
# Remove them and replace with the standard vSphere SDK boilerplate to extract the script from LML.
# load the configuration. Is provided by %CONFIG then
my $C = new LML::Config;
# connect to vSphere
get_vi_connection();

my $filter = {};
if ( my $matchhosts = param("matchhosts") ) {
    $filter = { "name" => qr($matchhosts)i };
}

my $alloweddeviation = param("alloweddeviation")
    ? (validate_with(param("alloweddeviation"), $VALIDATE_INTEGER) ?: 5)
    : 5;    # in seconds

my @hostlist = @{
    Vim::find_entity_views(
                            view_type    => "HostSystem",
                            filter       => $filter,
                            begin_entity => Vim::get_service_content()->rootFolder,
                            properties   => [ "configManager.dateTimeSystem", "name" ] ) };

#Result: Array of
#HostSystem=HASH(0x60ccf20)
#      'configManager.dateTimeSystem' => ManagedObjectReference=HASH(0x61bd398)
#         'type' => 'HostDateTimeSystem'
#         'value' => 'dateTimeSystem-872'
#      'mo_ref' => ManagedObjectReference=HASH(0x60cce18)
#         'type' => 'HostSystem'
#         'value' => 'host-872'
#      'name' => 'esx.server.domain.fqdn'

my $datetimehosts = { map { $_->{"configManager.dateTimeSystem"}->{value} => $_->{name} } @hostlist };
#Result: Reference of Hash of
#   'dateTimeSystem-872' => 'esx.server.domain.fqdn'

my @datetimemo_refs = map { $_->{"configManager.dateTimeSystem"} } @hostlist;
#Result: Array of
#ManagedObjectReference=HASH(0x5fdf470)
#   'type' => 'HostDateTimeSystem'
#   'value' => 'dateTimeSystem-1060'

my @datetimeviews = @{ Vim::get_views( mo_ref_array => \@datetimemo_refs ) };
#Result: Array of
#HostDateTimeSystem=HASH(0x60ce8b0)
#      'dateTimeInfo' => HostDateTimeInfo=HASH(0x60ce9d0)
#         'ntpConfig' => HostNtpConfig=HASH(0x60ce970)
#            'server' => ARRAY(0x60cec10)
#               0  'ntp.server.fqdn'
#         'timeZone' => HostDateTimeSystemTimeZone=HASH(0x60ce838)
#            'description' => 'UTC'
#            'gmtOffset' => 0
#            'key' => 'UTC'
#            'name' => 'UTC'
#      'mo_ref' => ManagedObjectReference=HASH(0x61bd878)
#         'type' => 'HostDateTimeSystem'
#         'value' => 'dateTimeSystem-872'

# I am not sure if this implementation is a good idea: We first query all hosts and then we compare their time stamp.
# Advantage is that it is easier to write down, disadvantage is that we can't be more precise than the time it took to
# do all these queries. In my tests even with a bunch of ESX servers the computetime stayed very small (1-2 secs) so
# I think that this cheap approach is a good start.
my $starttime = time;
my $result = {
    systems => {
        map( {
               $datetimehosts->{ $_->{mo_ref}->{value} } => { stamp => $_->QueryDateTime, ntp => $_->{dateTimeInfo}->{ntpConfig}->{server} }
            } @datetimeviews ),
        #Result: Reference of Hash of
        #    'esx.server.domain.fqdn' => HASH(0x60ceb80)
        #          'ntp' => ARRAY(0x61954e0)
        #             0  'ntp.server.fqdn'
        #          'stamp' => '2013-03-07T09:40:51.44303Z'
        $ENV{VI_SERVER} => {
                             stamp => Vim::get_view(
                                                     mo_ref =>
                                                       ManagedObjectReference->new(
                                                                                    type  => 'ServiceInstance',
                                                                                    value => 'ServiceInstance'
                                                       )
                               )->CurrentTime
        }
    },
};
# how long did it take to produce the result (querying all the hosts)?
my $computetime = time - $starttime;
if ( $computetime > $alloweddeviation ) {
    # if it took longer to get the results than the allowed deviation then we must increase the allowed deviation
    $alloweddeviation = $computetime;
}
# our reference time is exactly in the middle of the time it took to compute the results
my $referencetime = int( $starttime + 0.5 * $computetime );

# Not really sure about the whole time zone thing. vSphere seems to always return UTC times,
# so we also use that for everything.
$result->{referencetime}    = DateTime->now( epoch=>$referencetime, time_zone => "UTC" )->datetime."Z";
$result->{alloweddeviation} = $alloweddeviation;
$result->{computetime}      = $computetime;

# compare time stamps to referencetime and collect out-of-sync hosts
my @badsystems = ();
while ( my ( $host, $data ) = each %{ $result->{systems} } ) {
    $data->{deviation} = int( abs( $referencetime - str2time( $data->{stamp} ) ) );
    if ( $data->{deviation} > $alloweddeviation
         or ( exists $data->{ntp} and not scalar( $data->{ntp} ) ) )
    {
        push( @badsystems, $host );
    }
}
$result->{badsystems} = \@badsystems;
$result->{message} = (@badsystems ? "System time more than $alloweddeviation seconds out of sync or no NTP servers set: " : "").join(" ",@badsystems);
$result->{status} = @badsystems > 0 ? 2 : 0;
$result->{version} = "$LML_VERSION";
print header( -type => "application/json" ) . to_json( $result, { utf8 => 0, pretty => 1, allow_blessed => 1, canonical => 1 } );
