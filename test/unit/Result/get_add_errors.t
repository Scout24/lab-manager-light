use strict;
use warnings;

use Test::More;

use LML::Config;

BEGIN {
    use_ok "LML::Result";
}

my $result = new_ok( "LML::Result" => [ new LML::Config( {} ), "http://foo.bar/boot/pxelinux.cfg/12345-123-123" ] );

is_deeply( [ $result->get_errors ], [], "should return empty list" );
is_deeply( [ $result->add_error( "a", "b", "c" ) ], [ "a", "b", "c" ], "first call should return arguments" );
is_deeply( [ $result->add_error( "a", "b", "c" ) ], [ "a", "b", "c", "a", "b", "c" ], "second call should return the arguments from first and second call" );

# NOTE: CGI output is \r\n !!
is(
    $result->render, "Status: 200 OK, Errors: a, b, c, a, b, c\r
Content-Type: text/plain; charset=ISO-8859-1\r
\r
", "should render status with errors"
);

is_deeply( [ $result->get_errors ], [ "a", "b", "c", "a", "b", "c" ], "should return list of errors" );

# test the set functions
is( $result->set_redirect_target("menu/server.txt"),     "menu/server.txt",            "should return argument" );
is( $result->set_statusinfo("force boot from LML config"), "force boot from LML config", "should return argument" );
is(
    $result->render, "Status: 200 OK and force boot from LML config, Errors: a, b, c, a, b, c\r
Content-Type: text/plain; charset=ISO-8859-1\r
\r
", "should render status with errors and without redirect"
);

done_testing();
