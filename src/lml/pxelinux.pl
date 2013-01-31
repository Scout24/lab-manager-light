#!/usr/bin/perl
#
#
# pxelinux.pl	Lab Manager Light pxelinux interface
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
use lib "$FindBin::RealBin/lib";

use CGI ':standard';
use LML::Common;
use LML::Subversion;
use LML::VMware;
use LML::DHCP;



# our URL base from REQUEST_URI
our $base_url = url();
$base_url =~ s/\/[^\/]+$//; # cheap basename()
my $tftp_url = $base_url;
$tftp_url =~ s/\/pxelinux.cfg.*$//; # strip trailing pxelinux.cfg

# install die handler to report fatal errors
$SIG{__DIE__} = sub { 
	die @_ if $^S; # see http://perldoc.perl.org/functions/die.html at the end
	return unless (
		(exists($CONFIG{lml}{showfatalerrors}) and $CONFIG{lml}{showfatalerrors}) and
		(exists($CONFIG{pxelinux}{fatalerror_template}) and $CONFIG{pxelinux}{fatalerror_template})
		);
	my $message = shift;
	chomp($message); # remove trailing newlines
	$message =~ s/\n/; /; # turn message into single line
	print header(-status=>'200 Fatal Error',-type=>'text/plain');
	my $body = join("\n",@{$CONFIG{pxelinux}{fatalerror_template}})."\n";
	$body =~ s/MESSAGE/$message/;
	print $body;
};

# input parameter, UUID of a VM
my $search_uuid;
if (param('uuid')) {
	$search_uuid=param('uuid');
} elsif (@ARGV) {
	$search_uuid=lc($ARGV[0]);
} else {
	die("Give UUID address as query parameter 'uuid' or as command line parameter\n");
}

my $vm_name="";
my @error=();

# connect to vSphere
connect_vi();

# get dump of single VM from vSphere
my %VM = get_vm_data($search_uuid);
#

# $LAB describes our internal view of the lab that lml manages
# used mainly to react to renamed VMs or VMs with changed MAC adresses
my $LAB={};
if (-r "$CONFIG{lml}{datadir}/lab.conf") {
	local $/=undef;
	open(LAB_CONF,"<$CONFIG{lml}{datadir}/lab.conf") || die "Could not open $CONFIG{lml}{datadir}/lab.conf";
	flock(LAB_CONF, 1) || die;
	binmode LAB_CONF;
	eval <LAB_CONF> || die "Could not parse $CONFIG{lml}{datadir}/lab.conf";
	close(LAB_CONF);
} else {
	# set up empty structure if our data file is missing
	$LAB->{HOSTS} = {};
}
die '$LAB is empty' unless (scalar(%{$LAB}));

# prepare some configuration variables
#
my @vsphere_networks=();
if (exists($CONFIG{vsphere}{networks}) and $CONFIG{vsphere}{networks}) {
    if (ref($CONFIG{vsphere}{networks})) {
        @vsphere_networks=@{$CONFIG{vsphere}{networks}};
    } else {
        @vsphere_networks=($CONFIG{vsphere}{networks});
    }
}

my $hosts_changed=0;

# if there are VMs and if we find the VM we are looking for:
if (scalar(keys(%VM)) and exists($VM{$search_uuid})) {
	$vm_name=$VM{$search_uuid}{NAME};


	# check if we should handle this VM
    my @vm_lab_macs=();
	if (@vsphere_networks and exists($VM{$search_uuid}{NETWORKING}) and @{$VM{$search_uuid}{NETWORKING}}) {
		# check for each MAC of the VM if the network name is in the list
        for my $vm_network (@{$VM{$search_uuid}{NETWORKING}}) {
            if (grep {$_ eq $vm_network->{NETWORK}} @vsphere_networks) {
                push(@vm_lab_macs,$vm_network->{MAC});
            }
        }
		if (! @vm_lab_macs) {
			print header(-status=>"404 VM does not match LML networks and is out of scope",-type=>'text/plain');
            Util::disconnect;
			exit 0
		}
	}

	# modify VM if configured and current setting not as it should be (because the reconfigure VM task takes time)
	if (exists($CONFIG{MODIFYVM}{FORCENETBOOT}) and $CONFIG{MODIFYVM}{FORCENETBOOT} and
		(	# either the setting is not set at all or it is set but not equal to "allow:net"
			not exists($VM{$search_uuid}{EXTRAOPTIONS}{'bios.bootDeviceClasses'}) or	
			not "$VM{$search_uuid}{EXTRAOPTIONS}{'bios.bootDeviceClasses'}" eq "allow:net"
		)
	) {
		setVmExtraOptsM($VM{$search_uuid}{MO_REF},"bios.bootDeviceClasses","allow:net");
	}
	# check for FQDN in VM name
	if ($vm_name =~ m/\./) {
		push(@error,"FQDN not allowed in VM name");
	} 
	if ($vm_name =~ m/ /) {
		push(@error,"Spaces not allowed in VM name");
	} 
	if ($vm_name ne lc($vm_name)) {
		push(@error,"UpperCase letters not allowed in VM name");
	}
	# check VM name against pattern of allowed names
	if (exists ($CONFIG{HOSTRULES}{PATTERN}) and $vm_name !~ $CONFIG{HOSTRULES}{PATTERN}) {
		my $displaypattern=$CONFIG{HOSTRULES}{PATTERN};
		$displaypattern =~ s/\^/^^/g;
		push(@error,"VM name does not match '$displaypattern' pattern");
	}
	# check VM against forbidden DNS zones
	if (exists ($CONFIG{HOSTRULES}{DNSCHECKZONES}) and scalar(@{$CONFIG{HOSTRULES}{DNSCHECKZONES}})) {
		for my $z (@{$CONFIG{HOSTRULES}{DNSCHECKZONES}}) {
			if (scalar(gethostbyname($vm_name.".$z."))) {
				push(@error,"Name conflict with '$vm_name.$z.'");
			}
		}
	}
	# check that contact ID is set to a valid UNIX user 
	if (exists $VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{contactuserid_field}}) {
		my @pwnaminfo=getpwnam($VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{contactuserid_field}});
		unless (@pwnaminfo and scalar(@pwnaminfo) and $pwnaminfo[2] > $CONFIG{vsphere}{contactuserid_minuid})  {
			push(@error,"$CONFIG{vsphere}{contactuserid_field} '".$VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{contactuserid_field}}."' does not exist");
		}
	} else {
		push(@error,"Must set $CONFIG{vsphere}{contactuserid_field} to valid username");
	}
	# check that expiry date is set and valid
	if (exists $VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{expires_field}}) {
		my $expires;
		eval { 
			$expires=DateTime::Format::Flexible->parse_datetime($VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{expires_field}} , 
										european => ($CONFIG{vsphere}{expires_european}?1:0)
									) 
		};
		if ($@) {
			push(@error,"Cannot parse $CONFIG{vsphere}{expires_field} date '".$VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{expires_field}}."'");
		} elsif (DateTime->compare(DateTime->now(),$expires) > 0 ) {
			push(@error,"VM expired on ".$expires);
		}
		# implicit logic: If we got here without errors then the date is parsable and in the future
	} else {
		push(@error,"Must set $CONFIG{vsphere}{expires_field} to valid date or date/time");
	}

	# TODO: The following test fails to notice name conflicts against offline machines that do not have a DNS records at the moment
	# you might want to increase your lease time to counter this effect or add some code to compare the new name against
	# the list of known hostnames in $LAB
	#
	# if the host changed the name make sure that it does not conflict with an existing name in our domain
	if (exists($LAB->{HOSTS}->{$search_uuid}->{HOSTNAME})) {
		if (not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} and
			scalar(gethostbyname($vm_name.".".$CONFIG{DHCP}{APPENDDOMAIN}."."))) {
				#print STDERR Dumper(gethostbyname($vm_name.".".$CONFIG{DHCP}{APPENDDOMAIN}."."));
				push(@error,"Renamed VM name exists already in '$CONFIG{DHCP}{APPENDDOMAIN}'");
		}
	} elsif (exists($CONFIG{HOSTRULES}{DNSCHECKNEW}) and $CONFIG{HOSTRULES}{DNSCHECKNEW} and
		scalar(gethostbyname($vm_name.".".$CONFIG{DHCP}{APPENDDOMAIN}."."))) {
		# if this is a brand-new machine (e.g. we have no history of it) and new VM checking is enabled
			push(@error,"New VM name exists already in '$CONFIG{DHCP}{APPENDDOMAIN}'");
	}

	# up till here we have only checks that verify the VM.
	# in case of errors stop processing so that we do not create host records anywhere as long
	# as some conditions are unmet.

	if (not scalar(@error)) {
		# we only modify something if there are no errors
	
		# check host-name directory existance in SVN if configured. If none of the actions are configured, ignore this test.
		if (
			(exists($CONFIG{SUBVERSION}{HOSTDIRS}) and $CONFIG{SUBVERSION}{HOSTDIRS}) &&
			(
				(exists($CONFIG{SUBVERSION}{CREATEHOSTDIRS}) and $CONFIG{SUBVERSION}{CREATEHOSTDIRS}) ||
				(exists($CONFIG{SUBVERSION}{FAILONMISSINGHOSTDIR}) and $CONFIG{SUBVERSION}{FAILONMISSINGHOSTDIR})
			)
		) {
			# check if the host dir exists
			my $newhostdir=$CONFIG{SUBVERSION}{HOSTDIRS}."/".$vm_name;
			my $havehostdir=svnCheckPath($newhostdir);

			# if CREATEHOSTDIRS is set, create missing host dirs
			if (exists($CONFIG{SUBVERSION}{CREATEHOSTDIRS}) and $CONFIG{SUBVERSION}{CREATEHOSTDIRS}) {
				if ($havehostdir) {
					# do nothing, be happy
				} else {

					# hostdir is missing, should we rename it from old
					# putting all the conditions for a move into the same if saves us the trouble
					# of having several branches of logic leading to a copy :-(
					if (	exists($CONFIG{SUBVERSION}{RENAMEHOSTDIRS}) and $CONFIG{SUBVERSION}{RENAMEHOSTDIRS} and
						exists($LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}) and
						(not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}) and
						svnCheckPath($CONFIG{SUBVERSION}{HOSTDIRS}."/".$LAB->{HOSTS}->{$search_uuid}->{HOSTNAME})) {
							if (not svnMovePath($CONFIG{SUBVERSION}{HOSTDIRS}."/".$LAB->{HOSTS}->{$search_uuid}->{HOSTNAME},
									$newhostdir)) {
								push(@error,"Could not move old hostdir to new hostdir in SVN");
							}
					} else {
						if (not svnCopyPath($CONFIG{SUBVERSION}{HOSTSKEL},$newhostdir)) {
							push(@error,"Could not create hostdir in SVN");
						}
					}
		
				}
			} else {
				# if we should not create the hostdirs, at least warn about missing host dir or let it pass
				push(@error,"SVN hostdir '$newhostdir' missing") if (exists($CONFIG{SUBVERSION}{FAILONMISSINGHOSTDIR}) and $CONFIG{SUBVERSION}{FAILONMISSINGHOSTDIR});
			}
		} # hostdirs is set

        # add lastseen info to host
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN} = time;
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN_DISPLAY} = POSIX::strftime("%a %b %e %H:%M:%S %Y", localtime);
		# create HOSTS record for DHCP if it has changed (name or networking)
		# ~~ compares array since perl 5.10!!
		#
		# NOTE: This should be after all other pieces of code that compare with the old host name !!!
		if (not (exists($LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}) and exists($LAB->{HOSTS}->{$search_uuid}->{MACS})) or
			not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} or 
			not @vm_lab_macs ~~ @{$LAB->{HOSTS}->{$search_uuid}->{MACS}} ) {
			$LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} = $vm_name;
            $LAB->{HOSTS}->{$search_uuid}->{MACS} = \@vm_lab_macs;
			$hosts_changed=1;
		}
	} # no errors in @error

} # if have $VM{$search_uuid}

# disconnect from VI
Util::disconnect;

# housekeeping needs to be in own script. This script has only the scope of a single VM.

# write dhcp-hosts.conf if it is configured and if we have host entries to write
if ($hosts_changed) {
    push(@error,UpdateDHCP($LAB));
}


if (scalar(@error)) {
	# have some errors
	print header('text/plain');
	print join("\n",@{$CONFIG{pxelinux}{error_main}})."\n"; # multiline values come as array
	print "menu title ".$CONFIG{pxelinux}{error_title}." ".$vm_name."\n";
	my $c=1;
	foreach my $e (@error) {
		print <<EOF;
label l$c
        menu label $c. $e
EOF
	print join("\n",@{$CONFIG{pxelinux}{error_item}})."\n";
		$c++;
	}
} elsif ($vm_name) {
	# if the VM is found and all is fine then redirect to default PXE configuration
	
	# dump $LAB to file only if all is fine. This makes sure that LML stays with the old view of the lab for some kind of
	# hard to catch errors.
	open(LAB_CONF,">$CONFIG{lml}{datadir}/lab.conf") || die "Could not open '$CONFIG{lml}{datadir}/lab.conf' for writing";
	flock(LAB_CONF, 2) || die;
    print LAB_CONF "# pxelinux.pl ".POSIX::strftime("%Y-%m-%d %H:%M:%S\n", localtime())."\n";
	print LAB_CONF Data::Dumper->Dump([$LAB],[qw(LAB)]);
	close(LAB_CONF);

	my $pxelinux_config_url;
	my $bootinfo;
	if ($CONFIG{pxelinux}{pxelinuxcfg_path} and $CONFIG{vsphere}{forceboot_field} and 
		exists $VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{forceboot_field}} and
		$VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{forceboot_field}}
	) {
		my $forceboot=$VM{$search_uuid}{CUSTOMFIELDS}{$CONFIG{vsphere}{forceboot_field}};
		# little exploit protection, could be done more professional :-)
		$forceboot =~ s/\.{2,}//g; # remove any .. or ... 
		$forceboot =~ tr[:/A-Za-z0-9._-][]dc; # normalize to contain only valid path characters
		# if forceboot contains a path relative to the pxelinux TFTP prefix
		if (-r $CONFIG{pxelinux}{pxelinuxcfg_path}."/".$forceboot and ! -d $CONFIG{pxelinux}{pxelinuxcfg_path}."/".$forceboot) {
			$pxelinux_config_url="$tftp_url/$forceboot";
			$bootinfo="force boot from VM config (file)";
		} elsif ($CONFIG{forceboot}{$forceboot}) {
			$pxelinux_config_url=($CONFIG{forceboot}{$forceboot} =~ m(://)?"":$tftp_url."/").$CONFIG{forceboot}{$forceboot};
			$bootinfo="force boot from LML config";
		} elsif ($forceboot =~ m(://)) {
			$pxelinux_config_url=$forceboot;
			$bootinfo="force boot from VM config (URL)";
		}
		else {
			warn("Invalid/Unknown force boot target '$forceboot' ignored");
		}
	}
	$pxelinux_config_url=$base_url."/default" unless ($pxelinux_config_url);
	$bootinfo="all is fine" unless ($bootinfo);
	print header(-status=>"302 VM is $vm_name and $bootinfo".($hosts_changed?", some hosts changed":""),-type=>'text/plain',-location=>$pxelinux_config_url);
} else {
	# if the VM is not found then also give some error text
	if (exists($CONFIG{PXELINUX}{REDIRECT_UNKNOWN_TO_DEFAULT}) and $CONFIG{PXELINUX}{REDIRECT_UNKNOWN_TO_DEFAULT}) {
		print header(-status=>'302 VM not found',-type=>'text/plain',-location=>$base_url."/default");
	} else {
		print header(-status=>404,-type=>'text/plain');
	}
	print "No VM found for '$search_uuid'\n";
}
#print Data::Dumper->Dump([\%CONFIG,\%VM,$LAB],[qw(CONFIG VM LAB)]);
