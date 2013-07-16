use strict;
use warnings;

use Test::More;
use Test::Warn;
use LML::VM;

my $VM = new_ok(
    "LML::VM" => [ {
        # nothing required, empty hash prevents data retrieval from backend
    } ] );
is ($VM->dns_domain,undef,"DNS domain is undef if not set");
$VM->set_dns_domain("foobar");
is ($VM->dns_domain,"foobar","DNS domain matches what we put int");
done_testing;
