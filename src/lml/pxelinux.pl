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
$base_url =~ s/\/[^\/]+$//;    # cheap basename()
my $tftp_url = $base_url;
$tftp_url =~ s/\/pxelinux.cfg.*$//;    # strip trailing pxelinux.cfg

# install die handler to report fatal errors
$SIG{__DIE__} = sub {
    die @_ if $^S;                     # see http://perldoc.perl.org/functions/die.html at the end
    return unless ( Config( "lml", "showfatalerrors" ) and Config( "pxelinux", "fatalerror_template" ) );
    my $message = shift;
    chomp($message);                   # remove trailing newlines
    $message =~ s/\n/; /;              # turn message into single line
    print header( -status => '200 Fatal Error', -type => 'text/plain' );
    my $body = join( "\n", @{ Config( "pxelinux", "fatalerror_template" ) } ) . "\n";
    $body =~ s/MESSAGE/$message/;
    print $body;
};

# input parameter, UUID of a VM
my $search_uuid;
if ( param('uuid') ) {
    $search_uuid = param('uuid');
} elsif (@ARGV) {
    $search_uuid = lc( $ARGV[0] );
} else {
    die("Give UUID address as query parameter 'uuid' or as command line parameter\n");
}

my $vm_name = "";
my @error   = ();

# connect to vSphere
connect_vi();

# get dump of single VM from vSphere
my %VM = get_vm_data($search_uuid);

#

my $LAB = ReadLabFile;

# prepare some configuration variables
#
my @vsphere_networks = ();
my $config_vsphere_networks = Config( "vsphere", "networks" );
if ($config_vsphere_networks) {
    if ( ref($config_vsphere_networks) ) {
        @vsphere_networks = @{$config_vsphere_networks};
    } else {
        @vsphere_networks = ($config_vsphere_networks);
    }
}

my $hosts_changed = 0;

# keep force boot info for later
my $pxelinux_config_url;
my $bootinfo;

# if there are VMs and if we find the VM we are looking for:
if ( scalar( keys(%VM) ) and exists( $VM{$search_uuid} ) ) {
    $vm_name = $VM{$search_uuid}{NAME};

    # check if we should handle this VM
    my @vm_lab_macs = ();
    if ( @vsphere_networks and exists( $VM{$search_uuid}{NETWORKING} ) and @{ $VM{$search_uuid}{NETWORKING} } ) {

        # check for each MAC of the VM if the network name is in the list
        for my $vm_network ( @{ $VM{$search_uuid}{NETWORKING} } ) {
            if ( grep { $_ eq $vm_network->{NETWORK} } @vsphere_networks ) {
                push( @vm_lab_macs, $vm_network->{MAC} );
            }
        }
        if ( !@vm_lab_macs ) {
            print header( -status => "404 VM does not match LML networks and is out of scope", -type => 'text/plain' );
            Util::disconnect;
            exit 0;
        }
    }

    # modify VM if configured and current setting not as it should be (because the reconfigure VM task takes time)
    if (
        Config( "modifyvm", "forcenetboot" ) and (    # either the setting is not set at all or it is set but not equal to "allow:net"
              not exists( $VM{$search_uuid}{EXTRAOPTIONS}{'bios.bootDeviceClasses'} ) or not "$VM{$search_uuid}{EXTRAOPTIONS}{'bios.bootDeviceClasses'}" eq "allow:net"
        )
      )
    {
        setVmExtraOptsM( $VM{$search_uuid}{MO_REF}, "bios.bootDeviceClasses", "allow:net" );
    }

    # check for FQDN in VM name
    if ( $vm_name =~ m/\./ ) {
        push( @error, "FQDN not allowed in VM name" );
    }
    if ( $vm_name =~ m/ / ) {
        push( @error, "Spaces not allowed in VM name" );
    }
    if ( $vm_name ne lc($vm_name) ) {
        push( @error, "UpperCase letters not allowed in VM name" );
    }

    # check VM name against pattern of allowed names
    my $hostrulespattern = Config( "hostrules", "pattern" );
    if ( $hostrulespattern and $vm_name !~ $hostrulespattern ) {
        my $displaypattern = $hostrulespattern;
        $displaypattern =~ s/\^/^^/g;    # pxelinux menu uses ^ to mark keyboard shortcuts. ^^ comes out as plain ^
        push( @error, "VM name does not match '$displaypattern' pattern" );
    }

    # check VM against forbidden DNS zones
    my $dnscheckzones = Config( "HOSTRULES", "DNSCHECKZONES" );
    if ( scalar( @{$dnscheckzones} ) ) {
        for my $z ( @{$dnscheckzones} ) {
            if ( scalar( gethostbyname( $vm_name . ".$z." ) ) ) {
                push( @error, "Name conflict with '$vm_name.$z.'" );
            }
        }
    }

    # check that contact ID is set to a valid UNIX user
    my $contactuserid_field  = Config( "vsphere", "contactuserid_field" );
    my $contactuserid_minuid = Config( "vsphere", "contactuserid_minuid" );
    if (     $contactuserid_field
         and exists $VM{$search_uuid}{CUSTOMFIELDS}{$contactuserid_field}
         and $contactuserid_minuid )
    {
        my $contactuserid = $VM{$search_uuid}{CUSTOMFIELDS}{$contactuserid_field};
        my @pwnaminfo     = getpwnam($contactuserid);
        unless ( @pwnaminfo and scalar(@pwnaminfo) and $pwnaminfo[2] > $contactuserid_minuid ) {
            push( @error, "$contactuserid_field '" . $contactuserid . "' does not exist" );
        }
    } else {
        push( @error, "Must set $contactuserid_field to valid username" );
    }

    # check that expiry date is set and valid
    my $expires_field = Config( "vsphere", "expires_field" );
    if ( exists $VM{$search_uuid}{CUSTOMFIELDS}{$expires_field} ) {
        my $vmdate = $VM{$search_uuid}{CUSTOMFIELDS}{$expires_field};
        my $expires;
        eval { $expires = DateTime::Format::Flexible->parse_datetime( $vmdate, european => ( Config( "vsphere", "expires_european" ) ? 1 : 0 ) ) };
        if ($@) {
            push( @error, "Cannot parse $expires_field date '" . $vmdate . "'" );
        } elsif ( DateTime->compare( DateTime->now(), $expires ) > 0 ) {
            push( @error, "VM expired on " . $expires );
        }

        # implicit logic: If we got here without errors then the date is parsable and in the future
    } else {
        push( @error, "Must set $expires_field to valid date or date/time" );
    }

    # TODO: The following test fails to notice name conflicts against offline machines that do not have a DNS records at the moment
    # you might want to increase your lease time to counter this effect or add some code to compare the new name against
    # the list of known hostnames in $LAB
    #
    # if the host changed the name make sure that it does not conflict with an existing name in our domain
    my $appendomain = Config( "dhcp",      "appenddomain" );
    my $dnschecknew = Config( "hostrules", "dnschecknew" );
    if ( exists( $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} ) ) {
        my $vm_fqdn = $vm_name . ".$appendomain.";
        if ( not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}
             and scalar( gethostbyname($vm_fqdn) ) )
        {
            Debug( Dumper( gethostbyname($vm_fqdn) ) ) if ($isDebug);
            push( @error, "Renamed VM '$vm_fqdn' name exists already in '$appendomain'" );

        } elsif ( $dnschecknew and scalar( gethostbyname($vm_fqdn) ) ) {

            # if this is a brand-new machine (e.g. we have no history of it) and new VM checking is enabled
            push( @error, "New VM name exists already in '$appendomain'" );
        }
    }

    # check force boot configuration
    my $pxelinuxcfg_path = Config("pxelinux","pxelinuxcfg_path");
    my $forceboot_field = Config("vsphere","forceboot_field");
    if (     $pxelinuxcfg_path and $forceboot_field
         and exists $VM{$search_uuid}{CUSTOMFIELDS}{ $forceboot_field }
         and $VM{$search_uuid}{CUSTOMFIELDS}{ $forceboot_field } )
    {
        my $forceboot = $VM{$search_uuid}{CUSTOMFIELDS}{ $forceboot_field };

        # little exploit protection, could be done more professional :-)
        $forceboot =~ s/\.{2,}//g;               # remove any .. or ...
        $forceboot =~ tr[:/A-Za-z0-9._-][]dc;    # normalize to contain only valid path characters
                                                 # if forceboot contains a path relative to the pxelinux TFTP prefix
        if ( -r $pxelinuxcfg_path . "/" . $forceboot and !-d $pxelinuxcfg_path . "/" . $forceboot ) {
            $pxelinux_config_url = "$tftp_url/$forceboot";
            $bootinfo            = "force boot from VM config (file)";
        } elsif ( my $forceboot_dest = Config("forceboot",$forceboot) ) {
            $pxelinux_config_url = ( $forceboot_dest =~ m(://) ? "" : $tftp_url . "/" ) . $forceboot_dest;
            $bootinfo = "force boot from LML config";
        } elsif ( $forceboot =~ m(://) ) {
            $pxelinux_config_url = $forceboot;
            $bootinfo            = "force boot from VM config (URL)";
        } elsif ( $forceboot eq "fatalerror" ) {
            die("Enjoy this fatal error, you called for it.\n");
        } elsif ( Config("lml","failoninvalidforceboot") ) {
            push( @error, "Invalid force boot target '$forceboot'" );
        }    # else do nothing to silently ignore invalid force boot targets
    }

    # up till here we have only checks that verify the VM.
    # in case of errors stop processing so that we do not create host records anywhere as long
    # as some conditions are unmet.

    if ( not scalar(@error) ) {

        # we only modify something if there are no errors

        # check host-name directory existance in SVN if configured. If none of the actions are configured, ignore this test.
        if (
             ( Config("subversion","hostdirs") 
             && ( Config("subversion","createhostdirs") || Config("subversion","failonmissinghostdir")  ) )
          )
        {

            # check if the host dir exists
            my $newhostdir  = Config("subversion","hostdirs") . "/" . $vm_name;
            my $havehostdir = svnCheckPath($newhostdir);

            # if CREATEHOSTDIRS is set, create missing host dirs
            if ( Config("subversion","createhostdirs") ) {
                if ($havehostdir) {

                    # do nothing, be happy
                } else {

                    # hostdir is missing, should we rename it from old
                    # putting all the conditions for a move into the same if saves us the trouble
                    # of having several branches of logic leading to a copy :-(
                    if (     Config("subversion","renamehostdirs")
                         and exists( $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} )
                         and ( not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} )
                         and svnCheckPath( Config("subversion","hostdirs") . "/" . $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} ) )
                    {
                        if ( not svnMovePath( Config("subversion","hostdirs") . "/" . $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}, $newhostdir ) ) {
                            push( @error, "Could not move old hostdir to new hostdir in SVN" );
                        }
                    } else {
                        if ( not svnCopyPath( Config("subversion","hostskel"), $newhostdir ) ) {
                            push( @error, "Could not create hostdir in SVN" );
                        }
                    }

                }
            } else {

                # if we should not create the hostdirs, at least warn about missing host dir or let it pass
                push( @error, "SVN hostdir '$newhostdir' missing" ) if ( Config("subversion","failonmissinghostdir") );
            }
        }    # hostdirs is set

        # add lastseen info to host
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN} = time;
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN_DISPLAY} = POSIX::strftime( "%a %b %e %H:%M:%S %Y", localtime );

        # create HOSTS record for DHCP if it has changed (name or networking)
        # ~~ compares array since perl 5.10!!
        #
        # NOTE: This should be after all other pieces of code that compare with the old host name !!!
        if (    not( exists( $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} ) and exists( $LAB->{HOSTS}->{$search_uuid}->{MACS} ) )
             or not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}
             or not @vm_lab_macs ~~ @{ $LAB->{HOSTS}->{$search_uuid}->{MACS} } )
        {
            $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} = $vm_name;
            $LAB->{HOSTS}->{$search_uuid}->{MACS}     = \@vm_lab_macs;
            $hosts_changed                            = 1;
        }
    }    # no errors in @error

}    # if have $VM{$search_uuid}

# disconnect from VI
Util::disconnect;

# housekeeping is in tools/lml-maintenance.pl. This script has only the scope of a single VM.

# write dhcp-hosts.conf if it is configured and if we have host entries to write
if ($hosts_changed) {
    push( @error, UpdateDHCP($LAB) );
}

if ( scalar(@error) ) {

    # have some errors
    print header( -status => "200 Errors: " . join( ", ", @error ), -type => 'text/plain' );
    print join( "\n", @{ Config("pxelinux","error_main") } ) . "\n";    # multiline values come as array
    print "menu title " . Config("pxelinux","error_title") . " " . $vm_name . "\n";
    my $c = 1;
    foreach my $e (@error) {
        print <<EOF;
label l$c
        menu label $c. $e
EOF
        print join( "\n", @{ Config("pxelinux","error_item") } ) . "\n";
        $c++;
    }
} elsif ($vm_name) {

    # if the VM is found and all is fine then redirect to default PXE configuration

    # dump $LAB to file only if all is fine. This makes sure that LML stays with the old view of the lab for some kind of
    # hard to catch errors.
    my $labfile = Config("lml","datadir");
    open( LAB_CONF, ">","$labfile/lab.conf" ) || die "Could not open '$labfile' for writing\n";
    flock( LAB_CONF, 2 ) || die;
    print LAB_CONF "# pxelinux.pl " . POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime() ) . " for $vm_name ($search_uuid)\n";
    print LAB_CONF Data::Dumper->Dump( [$LAB], [qw(LAB)] );
    close(LAB_CONF);

    # these can be set by the force boot handling above
    $pxelinux_config_url = $base_url . "/default" unless ($pxelinux_config_url);
    $bootinfo            = "all is fine"          unless ($bootinfo);
    print header(
                  -status => "302 VM is $vm_name and $bootinfo" . ( $hosts_changed ? ", some hosts changed" : "" ),
                  -type => 'text/plain',
                  -location => $pxelinux_config_url
    );
} else {

    # if the VM is not found then also give some error text
    if ( Config("pxelinux","redirect_unknown_to_default") ) {
        print header(
                      -status   => '302 VM not found',
                      -type     => 'text/plain',
                      -location => $base_url . "/default"
        );
    } else {
        print header( -status => 404,
                      -type   => 'text/plain' );
    }
    print "No VM found for '$search_uuid'\n";
}

#print Data::Dumper->Dump([\%CONFIG,\%VM,$LAB],[qw(CONFIG VM LAB)]);
