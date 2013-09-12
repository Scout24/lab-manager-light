#!/usr/bin/perl
#
#
# setCustomValue.pl can be used to set any custom value

use strict;
use warnings;


# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Common;
use LML::VMware;
use LML::DHCP;

LoadConfig();

# input parameter, UUID of a VM
my $search_uuid=param('uuid')?lc(param('uuid')):lc($ARGV[0]);
my $key=param('key')?param('key'):$ARGV[1];
my $value=param('value')?param('value'):$ARGV[2];

if ($search_uuid and $key and $value) {
    print header('text/plain');
    setVmCustomValue($search_uuid,$key,$value);
} else {
    print header(-status=>404,-type=>'text/plain');
    print "URL call: uuid=...&key=...value=...\nCLI call: <uuid> <key> <value>\n";
}
