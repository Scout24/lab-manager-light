#
# functions for modifying VM related data
#

package LML::VMmodify;

use strict;
use warnings;

use Exporter;
use vars qw(
  $VERSION
  @ISA
  @EXPORT
);

our @ISA    = qw(Exporter);
our @EXPORT = qw(remove_forceboot);

use LML::Common;
use LML::VMware;

sub remove_forceboot($) {
    my $search_uuid = shift;

    # get dump of single VM from vSphere
    my %VM = LML::VMware::get_vm_data($search_uuid);
    my $forceboot_target_field = Config( "vsphere", "forceboot_target_field" );
    my $off_value = "OFF";

    # the new variant is to use the forceboot field as trigger, set a coherent value
    if ( not ( $forceboot_target_field and $VM{$search_uuid}{CUSTOMFIELDS}{$forceboot_target_field} ) ) {
        $off_value = "";
    }

    # unset forceboot in the determined way
    LML::VMware::setVmCustomValueU( $search_uuid, Config( "vsphere", "forceboot_field" ), $off_value );
}

1;