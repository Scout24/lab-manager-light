#!/usr/bin/perl
use strict;
use warnings;

my $LICENSE = "Licensed under the GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full license";

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";
use JSON;
use CGI ':standard';
use LML::Common;

my $result = {version => $LML_VERSION};

print header('application/json');
print encode_json( $result );
1;
