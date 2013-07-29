use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::Lab;
use LML::Config;

BEGIN {
    use_ok "LML::VMcreate::VMproperties";
}

my $C = new LML::Config( { vsphere => { expires_european => 1 }, hostrules => { pattern => '^(dev|tuv)[a-z]{3}[0-9]{2}$' } } );

throws_ok { new LML::VMcreate::VMproperties() } qr(must be an instance of LML::Config), "dies on value for config is not defined";

throws_ok {
    new LML::VMcreate::VMproperties(
        $C,
        {
          name       => "devxxx002",                                                                                              # invalid name pattern
          expiration => "31.12.2019",
          username   => "testuser",
        }
    );
}
qr(invalid vm_name), "dies on invalid vm name";

throws_ok {
    new LML::VMcreate::VMproperties(
        $C,
        {
          name       => "devxxx02",
          expiration => "12.31asdf",    # invalid expiration date pattern
          username   => "testuser",
        }
    );
}
qr(invalid expiration_date), "dies on invalid expiration date pattern";

new_ok(
        "LML::VMcreate::VMproperties" => [
                                           $C,
                                           {
                                             name       => "devxxx02",
                                             expiration => "31.12.2019",
                                             username   => "testuser",
                                           }
        ]
);

done_testing();
