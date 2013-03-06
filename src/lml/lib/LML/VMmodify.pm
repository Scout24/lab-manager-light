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
use LML::Config;
use Carp;
use Data::Dumper;
use LML::VMware;
use LML::VM;

sub remove_forceboot {
    my ( $C, $uuid ) = @_;
    croak( "1st parameter must be LML::Config object and not " . ref($C) . " in " . ( caller(0) )[3] )
      unless ( ref($C) eq "LML::Config" );
    croak( "2nd parameter must be uuid and not '" . ref($uuid) . "' in " . ( caller(0) )[3] )
      unless ( not ref($uuid) and $uuid );

    # get dump of single VM from vSphere
    if ( my $forceboot_field = $C->get( "vsphere", "forceboot_field" ) ) {
        if ( my $VM = new LML::VM($uuid) ) {

            my $forceboot_target_field = Config( "vsphere", "forceboot_target_field" );
            my $off_value = "OFF";

            # the new variant is to use the forceboot field as trigger, set a coherent value
            if ( not( $forceboot_target_field and $VM->{CUSTOMFIELDS}{$forceboot_target_field} ) ) {
                $off_value = "";
            }

            # unset forceboot in the determined way
            return setVmCustomValueU( $uuid, $forceboot_field, $off_value );
        } else {
            # bail out if not VM data available, probably no VM for this uuid
            Debug("No VM data for uuid '$uuid' found.");
            return 0;
        }
    } else {
        # bail out if not VM data available, probably no VM for this uuid
        Debug("[vsphere] forceboot_field not set.");
        return 0;
    }

}

1;
