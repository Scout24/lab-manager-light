#!/usr/bin/perl
#
#
# lml-maintenance.pl	Lab Manager Light maintenance script
#
# * Remove obsolete machines from lab.conf
#
# Authors:	
# GSS		Schlomo Schapiro <lml@schlomo.schapiro.org>
# 
# Copyright:	Schlomo Schapiro, Immobilien Scout GmbH
# License:	GNU General Public License, see http://www.gnu.org/licenses/gpl.txt for full text
#
#

use strict;
use warnings;


# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::RealBin/../lib";

use CGI ':standard';
use LML::Common;
use LML::Subversion;
use LML::VMware;
use LML::DHCP;

LoadConfig();

# connect to vSphere
connect_vi();

my $vm_name="";
my @error=();

# get a complete dump from vSphere - this is expensive and takes some time
my %VM = search_vm();

# dump %VM to file
my $vmfile = Config("lml","datadir")."/vm.conf";
open(VM_CONF, ">",$vmfile) || die "Could not open '$vmfile' for writing\n";
flock(VM_CONF, 2) || die;
print VM_CONF "# lml-maintenance.pl ".POSIX::strftime("%Y-%m-%d %H:%M:%S\n", localtime())."\n";
print VM_CONF Data::Dumper->Dump([\%VM],[qw(VM)]);
close(VM_CONF);

# $LAB describes our internal view of the lab that lml manages
# used mainly to react to renamed VMs or VMs with changed MAC adresses
my $LAB={};
my $labfile = Config("lml","datadir")."/lab.conf";
if (-r $labfile) {
    local $/=undef;
    open(LAB_CONF,"+<",$labfile) || die "Could not open '$labfile' for reading and writing\n";
    flock(LAB_CONF, 2) || die;
    binmode LAB_CONF;
    eval <LAB_CONF> || die "Could not parse $labfile\n";

    die '$LAB is empty' unless (scalar(%{$LAB}));

    my $hosts_removed=0;
    for my $uuid (keys(%{$LAB->{HOSTS}})) {
        if (! exists($VM{$uuid})) {
            print "Removing $uuid ".$LAB->{HOSTS}->{$uuid}->{HOSTNAME}." from inventory\n";
            $hosts_removed++;
            delete($LAB->{HOSTS}->{$uuid});
        }
    }

    # dump $LAB to file only if all is fine. This makes sure that LML stays with the old view of the lab for some kind of
    # hard to catch errors.
    if ($hosts_removed > 0) {
        seek(LAB_CONF,0,0);
        print LAB_CONF "# lml-maintenance.pl ".POSIX::strftime("%Y-%m-%d %H:%M:%S\n", localtime())."\n";
        print LAB_CONF Data::Dumper->Dump([$LAB],[qw(LAB)]);
        truncate(LAB_CONF,tell(LAB_CONF));
    }
    close(LAB_CONF);

    push(@error,UpdateDHCP($LAB));

} else {
    push(@error,"'$labfile' not found\n");
}

if (scalar(@error)) {
    print STDERR "ERROR: ".join("\nERROR: ",@error)."\n";
    exit 1;
}
