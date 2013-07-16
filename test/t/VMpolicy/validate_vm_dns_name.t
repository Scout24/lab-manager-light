use strict;
use warnings;

# mock gethostbyname so that we do not depend on external factors like working DNS
BEGIN {
    use Socket;

    sub gethostbyname {
        my $name = shift;
        # should return ($name,$aliases,$addrtype,$length,@addrs)
        my @result = ();
        @result = ( "dev123.test.data", "", 2, 4, inet_aton("1.2.3.4") ) if ( $name =~ /^dev123.test.data/ );
        #diag( "Mocking gethostbyname($name): " . join( ", ", @result ) );
        return @result;
    }
    *CORE::GLOBAL::gethostbyname = \*gethostbyname;

}
use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Common;
use LML::Config;
use LML::Result;
use LML::VM;

use LML::Lab;

use_ok "LML::VMpolicy";

# load shipped configuration
my $C = new LML::Config( "src/lml/default.conf", "test/data/test.conf" );

#$isDebug = 1;

######## validate_vm_dns_name
#
#
#
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config(
                                                { "dhcp" => { "managed_networks" => [ "gaga", "arc.*" ] }, }
                                 ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "UUID"       => "01234",
                                                "dns_domain" => "test.data",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "01:02:03:04:00:15",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "99:02:03:04:00:15",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_vm_dns_name( new LML::Lab( { "HOSTS" => { "01234" => { "HOSTNAME" => "dev123" } } } ) )
           ],
           [],
           "should not return error as new VM name equals old VM name, check managed_networks regex"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "dhcp" => {
                                                                "appenddomain"     => "junk.world",
                                                                "managed_networks" => ["arc.int"],
                                                    },
                                                  }
                                 ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "UUID"       => "01234",
                                                "dns_domain" => "junk.world",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "01:02:03:04:00:15",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "99:02:03:04:00:15",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_vm_dns_name( new LML::Lab( { "HOSTS" => {} } ) )
           ],
           [],
           "should not return error as VM is new and has no conflict with managed domain"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( { "dhcp" => { "managed_networks" => ["arc.int"], } } ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "UUID"       => "01234",
                                                "dns_domain" => "test.data",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "01:02:03:04:00:15",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "99:02:03:04:00:15",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_vm_dns_name( new LML::Lab( { "HOSTS" => {} } ) )
           ],
           ["New VM name exists already in 'test.data'"],
           "should return error as new VM name conflicts with managed domain"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "dhcp" => {
                                                                "appenddomain"     => "foobar",
                                                                "managed_networks" => ["arc.int"],
                                                    },
                                                    "appenddomains" => { "arc.int"  => "test.data" },
                                                    "hostrules"     => { "dnscheck" => 1 } }
                                 ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "UUID"       => "01234",
                                                "dns_domain" => "test.data",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "01:02:03:04:00:15",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "99:02:03:04:00:15",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_vm_dns_name( new LML::Lab( { "HOSTS" => {} } ) )
           ],
           ["New VM name exists already in 'test.data'"],
           "should return error as new VM name conflicts with managed domain, network as own appenddomain"
);
is_deeply( [
       new LML::VMpolicy(
           new LML::Config( {
                  "dhcp" => {
                              "appenddomain"     => "test.data",
                              "managed_networks" => ["arc.int"],
                  },
                  "hostrules" => { "dnscheck" => 1 } }
           ),
           new LML::VM( {
                          "NAME"       => "dev123",
                          "UUID"       => "01234",
                          "dns_domain" => "test.data",
                          "NETWORKING" => [ {
                                              "MAC"     => "01:02:03:04:00:15",
                                              "NETWORK" => "arc.int"
                                            },
                                            {
                                              "MAC"     => "99:02:03:04:00:15",
                                              "NETWORK" => "foo"
                                            }
                          ],
                        } )
         )->validate_vm_dns_name( new LML::Lab( { "HOSTS" => { "01234" => { "HOSTNAME" => "zzz" } } } ) )
    ],
    ["Renamed VM 'dev123.test.data.' exists already in 'test.data'"],
    "should return error as renamed VM name exists in managed domain"
);
is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config( {
                                                    "dhcp" => {
                                                                "appenddomain"     => "test.data",
                                                                "managed_networks" => ["arc.int"],
                                                    },
                                                  }
                                 ),
                                 new LML::VM( {
                                                "NAME"       => "frobinicate_foo_bar_baz",
                                                "UUID"       => "01234",
                                                "dns_domain" => "test.data",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "01:02:03:04:00:15",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "99:02:03:04:00:15",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_vm_dns_name( new LML::Lab( { "HOSTS" => { "01234" => { "HOSTNAME" => "dev123" } } } ) )
           ],
           [],
           "should return no error as renamed VM name has no conflict with managed domain"
);

done_testing();
