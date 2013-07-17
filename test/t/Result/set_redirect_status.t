use strict;
use warnings;

use Test::More;

use LML::Config;

BEGIN {
    use_ok "LML::Result";
}

my $result = new_ok( "LML::Result" => [ new LML::Config( {} ), "http://foo.bar/boot/pxelinux.cfg/12345-123-123" ] );
$result->set_redirect_target("menu/server.txt");
$result->set_statusinfo("force boot from LML config");
is_deeply($result->set_redirect_parameter( { hostname => 'test.test.loc' } ), { hostname => 'test.test.loc' }, "should set parameter hash");
is(
    $result->render, "Status: 200 OK and force boot from LML config\r
Location: http://foo.bar/boot/menu/server.txt?hostname=test.test.loc\r
Content-Type: text/plain; charset=ISO-8859-1\r
\r
", "should render status with redirect"
);
done_testing();
