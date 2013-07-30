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

my $C = new LML::Config( { vsphere => { expires_european => 1 }, hostrules => { pattern => '^[a-z]{6}[0-9]{2}$' } } );
my $lab = new LML::Lab( {} );

throws_ok { new LML::VMcreate::VMproperties() } qr(must be an instance of LML::Config), "dies on value for config is not defined";
throws_ok { new LML::VMcreate::VMproperties($C) } qr(must be an instance of LML::Lab), "dies on value for lab is not defined";

throws_ok {
    new LML::VMcreate::VMproperties(
        $C, $lab,
        {
          name       => "devxxx002",    # invalid name pattern
          expiration => "31.12.2019",
          username   => "testuser",
        }
    );
}
qr(invalid vm_name), "dies on invalid vm name";

throws_ok {
    new LML::VMcreate::VMproperties(
        $C, $lab,
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
                                           $C, $lab,
                                           {
                                             name       => "foobar02",
                                             expiration => "31.12.2019",
                                             username   => "testuser",
                                           }
        ]
);

{
    my $vm_properties = new_ok(
                                "LML::VMcreate::VMproperties" => [
                                                                   $C, $lab,
                                                                   {
                                                                     name              => "foobar01",
                                                                     username          => "testuser",
                                                                     expiration        => "31.12.2019",
                                                                     esx_host          => "esx_host.some.domain",
                                                                     folder            => "some/folder",
                                                                     force_boot_target => "some boot target",
                                                                     force_network     => "some network",
                                                                   }
                                ]
    );

    is_deeply(
        $vm_properties,

        {
           config            => $C,
           lab               => $lab,
           linebreak         => '\n',
           guestid           => 'rhel6_64Guest',
           custom_fields     => {},
           vm_name           => "foobar01",
           username          => "testuser",
           expiration_date   => "31.12.2019",
           esx_host          => "esx_host.some.domain",
           vm_folder         => "some/folder",
           force_boot_target => "some boot target",
           force_network     => "some network",
        },
        "should create vms_array with expected values"
    );
}

done_testing;
