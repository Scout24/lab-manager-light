use strict;
use warnings;

use Test::More;

BEGIN {
    require_ok "src/lml/tools/lml-maintenance.pl";
}

LoadConfig( "src/lml/default.conf", "test/data/test.conf" );

# test the maintenance routine start by read out test data
my $VM = ReadVmFile();

# we don't have to delete a vm from the vm hash, because 4213059e-70c2-6f34-1986-50463d0222f8
# already don't exist but is present in lab.conf. The maintain function will remove that
# host and LAB_OLD and LAB_NEW will be the same

# save the content from our test lab file and remove the selected host manually
my $LAB_OLD = ReadLabFile();
delete $LAB_OLD->{HOSTS}{'4213059e-70c2-6f34-1986-50463d0222f8'};
# execute the maintenance function which should remove the selected host above
maintain_labfile($VM);
# read out the lab file, which was modified previously
my $LAB_NEW = ReadLabFile();
# check if the selected host is gone
is_deeply($LAB_NEW, $LAB_OLD, "should fail, if maintain function do more/less than removing the single host");

done_testing;
