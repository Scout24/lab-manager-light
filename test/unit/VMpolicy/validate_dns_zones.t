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
        @result = ( "dev123.test2.data", "", 2, 4, inet_aton("1.2.3.4") ) if ( $name =~ /^dev123.test2.data/ );
        @result = ( "dev123.2nd.zone", "", 2, 4, inet_aton("1.2.3.4") ) if ( $name =~ /^dev123.2nd.zone/ );        
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

#$isDebug = 1;

######## validate_vm_dns_name
#
#
#
is_deeply( [
              new LML::VMpolicy(
                             new LML::Config( { "hostrules" => { "dnscheckzones" => [ "test.data", "test2.data", "test3.data" ], "dnscheck" => 1 } } ),
                             new LML::VM( { "NAME" => "dev123" } ) )->validate_dns_zones
           ],
           [ "Name conflict with 'dev123.test.data.'", "Name conflict with 'dev123.test2.data.'" ],
           "should return two error messages as we test dev123.test.data and dev123.test2.data"
);
is_deeply( [
              new LML::VMpolicy(
                             new LML::Config( { "hostrules" => { "dnscheckzones" => [ "test.data", "test2.data" ], "dnscheck" => 0 } } ),
                             new LML::VM( { "NAME" => "dev123" } ) )->validate_dns_zones
           ],
           [],
           "should return no error as dnscheck is disabled"
);

is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config(
                                                { "hostrules" => { "dnscheck" => "1", "dnscheckzones" => ["1st.zone"], },}
                                 ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_dns_zones()
           ],
           [],
           "should not return error as new VM name equals old VM name, check managed_networks regex"
);

is_deeply( [
              new LML::VMpolicy(
                                 new LML::Config(
                                                { "hostrules" => { "dnscheck" => "1", "dnscheckzones" => ["1st.zone"], }, }
                                 ),
                                 new LML::VM( {
                                                "NAME"       => "dev123",
                                                "NETWORKING" => [ {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "arc.int"
                                                                  },
                                                                  {
                                                                    "MAC"     => "egal",
                                                                    "NETWORK" => "foo"
                                                                  }
                                                ],
                                              } )
                )->validate_dns_zones("2nd.zone", "3rd.zone")
           ],
           ["Name conflict with 'dev123.2nd.zone.'"],
           "should not return error as new VM name equals old VM name, check managed_networks regex"
);
done_testing();
