#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../../lib";

use CGI ':standard';
use LML::Common;
use LML::Config;
use LML::Lab;
use JSON;

use User::pwent;

my $GECOS = {};    # cache for gecos lookups

my $C = new LML::Config();

my $LAB = new LML::Lab( $C->labfile );

print header('application/json');
print encode_json( \@CONFIGFILES );
1;
