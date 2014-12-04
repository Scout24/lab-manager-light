#!/usr/bin/perl
#
#
# setCustomValue.pl can be used to set any custom value

use strict;
use warnings;

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Config;
use LML::VMware;

my $C = new LML::Config();

my ( $key, $value ) = @ARGV;
$| = 1;
if ( defined $key and defined $value ) {
    print "Type YES to set '$key' to '$value' on all VMs: ";
    my $answer = <STDIN>;
    chomp($answer);
    if ( $answer eq "YES" ) {
        get_vi_connection();
        my $custom_fields = get_custom_fields();
        if ( defined $custom_fields->{$key} ) {
            my @good = ();
            my @bad  = ();
            print "Loading VMs: ";
            my $vms = Vim::find_entity_views(
                                              view_type    => "VirtualMachine",
                                              begin_entity => Vim::get_service_content()->rootFolder,
                                              properties   => ["name"] );
            if ( defined $vms and ref($vms) eq "ARRAY" ) {
                printf  "Found %d VMs\nSetting Custom Field: ",scalar(@$vms);
                foreach my $vm (@$vms) {
                    if ( setVmCustomValue( $vm, $key, $value ) ) {
                        push @good, $vm->{name};
                        print "+";
                    }
                    else {
                        push @bad, $vm->{name};
                        print "-";
                    }
                }
                printf "\n\n%d VMs modified successfully\n", scalar(@good);
                if (@bad) {
                    printf "%d VMs could not be modified:\n",scalar(@bad);
                    print STDERR join( "\n", @bad );
                }
            }
            else {
                print "Could not load VMs.\n";
            }
        }
        else {
            print "Custom Field '$key' not found in vSphere\n";
        }
    }
    else {
        print "You bailed out, I did nothing.\n";
    }
}
else {
    print "Usage: " . __FILE__ . " key value\nSet custom attribute key to value on ALL VMs\nIf it cannot be set for a VM then it will print the list of failed VMs to STDERR";
}
1;
