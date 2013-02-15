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
    my $uuid = shift;

    my $forceboot_field = Config( "vsphere", "forceboot_field" );
    unless ($forceboot_field) {
        # bail out if field not configured
        Debug("[vsphere] forceboot_field not set, bailing out") if ($isDebug);
        return 0;
    }

    # get dump of single VM from vSphere
    my %VM = get_vm_data($uuid);
    unless ( scalar( keys(%VM) ) ) {

        # bail out if not VM data available, probably no VM for this uuid
        Debug( "No VM data for uuid '$uuid' found, VM Data is\n" . join( ", ", keys(%VM) ) ) if ($isDebug);
        return 0;
    }

    my $forceboot_target_field = Config( "vsphere", "forceboot_target_field" );
    my $off_value              = "OFF";

    # the new variant is to use the forceboot field as trigger, set a coherent value
    if ( not( $forceboot_target_field and $VM{CUSTOMFIELDS}{$forceboot_target_field} ) ) {
        $off_value = "";
    }

    # unset forceboot in the determined way
    return setVmCustomValueU( $uuid, $forceboot_field, $off_value );
}

1;
