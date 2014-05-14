use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use LML::VMresources;
use LML::Lab;

BEGIN {
    use_ok "LML::VMplacement::Filters::ByDiskSpace";
}

##################################
# test setup
###################################

my $lab = new LML::Lab( {
       "DATASTORES" => {
           "datastore-1111" => {
                                 "freespace" => "10240"    # in Megabytes
           } } } );

my $obj = new_ok "LML::VMplacement::Filters::ByDiskSpace" => [$lab], "can create object";

ok( $obj->host_can_vm( 
                        { 
                            datastores => ["datastore-1111"], 
                            name => "foobar01" 
                        }, 
                        new LML::VMresources( 
                                            { disks => [ 
                                                        { 
                                                            size => 8 
                                                        } 
                                                       ],
                                              ram => 1024 
                                            } 
                                            ) 
                      ),
    "VM fits on host" 
    );
ok( ! $obj->host_can_vm( 
                        { 
                            datastores => ["datastore-1111"], 
                            name => "foobar01" 
                        }, 
                        new LML::VMresources( 
                                            { disks => [ 
                                                        { 
                                                            size => 12 
                                                        } 
                                                       ],
                                              ram => 2048 
                                            } 
                                            ) 
                      ),
    "VM does not fit on host, disk too large" 
    );
ok( ! $obj->host_can_vm( 
                        { 
                            datastores => ["datastore-1111"], 
                            name => "foobar01" 
                        }, 
                        new LML::VMresources( 
                                            { disks => [ 
                                                        { 
                                                            size => 8 
                                                        } 
                                                       ],
                                              ram => 20480 
                                            } 
                                            ) 
                      ),
    "VM does not fit on host, ram too large" 
    );
throws_ok { $obj->host_can_vm( {} ) } qr(missing data), "host without data fails";

done_testing();
