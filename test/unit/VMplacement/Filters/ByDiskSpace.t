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
                 "freespace" => "10737418240"
             }
       }
    } );


my $obj = new_ok "LML::VMplacement::Filters::ByDiskSpace" => [ $lab ], "can create object";

ok ( $obj->host_can_vm({datastores=>["datastore-1111"]},new LML::VMresources({disks=>[{size => 5737418240}]})), "VM fits on host");
ok ( ! $obj->host_can_vm({datastores=>["datastore-1111"]},new LML::VMresources({disks=>[{size => 20737418240}]})), "VM does not fit on host");

throws_ok { $obj->host_can_vm({}) } qr(missing data), "host without data fails";

done_testing();
