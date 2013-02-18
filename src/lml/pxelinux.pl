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
use LML::VMware;
use LML::VM;
use LML::Config;
use LML::VMpolicy;
use LML::DHCP;
use Data::Dumper;

my $C = new LML::Config();    # implicitly also fills %LML::Common::CONFIG

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

# read history to detect renamed VMs and to be able to update the DHCP
my $LAB = ReadLabFile;

# prepare some configuration variables
my @vsphere_networks = ();                                       # list of network names for which LML is responsible.
my $config_vsphere_networks = Config( "vsphere", "networks" );
if ($config_vsphere_networks) {
    if ( ref($config_vsphere_networks) eq "ARRAY" ) {
        @vsphere_networks = @{$config_vsphere_networks};
    } else {
        @vsphere_networks = ($config_vsphere_networks);
    }
}

my $has_changed = 0;

# keep force boot info for later
my $pxelinux_config_url;
my $bootinfo;

my $VM = new LML::VM($search_uuid);

# if there are VMs and if we find the VM we are looking for:
if ( %{$VM} and $VM->uuid and $search_uuid eq $VM->uuid ) {
    $vm_name = $VM->name;

    # check if we should handle this VM
    my @vm_lab_macs = $VM->get_macs_for_networks(@vsphere_networks);
    if ( !@vm_lab_macs ) {
        print header( -status => "404 VM does not match LML networks and is out of scope", -type => 'text/plain' );
        exit 0;
    }

    # modify VM if configured and current setting not as it should be (because the reconfigure VM task takes time)
    if ( Config( "modifyvm", "forcenetboot" ) and not $VM->forcenetboot ) {
        $VM->activate_forcenetboot;
    }

    my $Policy = new LML::VMpolicy( $C, $VM );

    push(
        @error,
        $Policy->validate_vm_name,
        $Policy->validate_hostrules_pattern,
        $Policy->validate_dns_zones,

    );

    #Debug(Data::Dumper->Dump([\@error],["error"]));
    # check that contact ID is set to a valid UNIX user
    my $contactuserid_field  = Config( "vsphere", "contactuserid_field" );
    my $contactuserid_minuid = Config( "vsphere", "contactuserid_minuid" );
    if (     $contactuserid_field
         and exists $VM->{CUSTOMFIELDS}{$contactuserid_field}
         and $contactuserid_minuid )
    {
        my $contactuserid = $VM->{CUSTOMFIELDS}{$contactuserid_field};
        my @pwnaminfo     = getpwnam($contactuserid);
        unless ( @pwnaminfo and scalar(@pwnaminfo) and $pwnaminfo[2] > $contactuserid_minuid ) {
            push( @error, "$contactuserid_field '" . $contactuserid . "' does not exist" );
        }
    } else {
        push( @error, "Must set $contactuserid_field to valid username" );
    }

    # check that expiry date is set and valid
    my $expires_field = Config( "vsphere", "expires_field" );
    if ( exists $VM->{CUSTOMFIELDS}{$expires_field} ) {
        my $vmdate = $VM->{CUSTOMFIELDS}{$expires_field};
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
    my $vm_fqdn = $vm_name . ".$appendomain.";
    if ( exists( $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} ) ) {
        if ( not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}
             and scalar( gethostbyname($vm_fqdn) ) )
        {
            Debug( Dumper( gethostbyname($vm_fqdn) ) ) if ($isDebug);
            push( @error, "Renamed VM '$vm_fqdn' name exists already in '$appendomain'" );
        }
    } elsif ( $dnschecknew and scalar( gethostbyname($vm_fqdn) ) ) {

        # if this is a brand-new machine (e.g. we have no history of it) and new VM checking is enabled
        push( @error, "New VM name exists already in '$appendomain'" );
    }

    # check force boot configuration
    my $pxelinuxcfg_path = Config( "pxelinux", "pxelinuxcfg_path" );
    my $forceboot_field  = Config( "vsphere",  "forceboot_field" );

    # this will be the triggers for deactivating forceboot. Every other value will be taken as TRUE!
    my @disabled_forceboot = ( "OFF", "", 0, "NO", "FALSE" );

    if (     $pxelinuxcfg_path
         and $forceboot_field
         and exists $VM->{CUSTOMFIELDS}{$forceboot_field}
         and $VM->{CUSTOMFIELDS}{$forceboot_field}
         and not grep { $_ eq uc( $VM->{CUSTOMFIELDS}{$forceboot_field} ) } @disabled_forceboot )
    {
        my $forceboot_target;    # Will be set in the next step, just to define with my
        my $forceboot              = $VM->{CUSTOMFIELDS}{$forceboot_field};
        my $forceboot_target_field = Config( "vsphere", "forceboot_target_field" );
        
        my $forceboot_target_value;
        if (defined $forceboot_target_field) {
            $forceboot_target_value = exists $VM->{CUSTOMFIELDS}{$forceboot_target_field} ? $VM->{CUSTOMFIELDS}{$forceboot_target_field} : "";
        } else {
            $forceboot_target_value = "";
        }

        # if the user is working with a forceboot_target_field
        # then take this value, ...
        if (     $forceboot_target_field
             and $forceboot_target_value )
        {
            $forceboot_target = $forceboot_target_value;
        }
        # else take the value from the forceboot field as target (old behaviour)
        else {
            # use forceboot default entry, if no target is given but the field exist
            if (    Config( "forceboot", "default" )
                and $forceboot_target_value eq ""
                and not $forceboot eq "fatalerror"        # because 'fatalerror' is hardcoded
                and not Config( "forceboot", $forceboot ) # because we can have any value for true, so filter out
              )
            {
                $forceboot_target = 'default';
            }
            # take the forceboot entry directly if nothing is matched above
            else {
                $forceboot_target = $forceboot;
            }
        }

        # little exploit protection, could be done more professional :-)
        # remove any .. or ...
        $forceboot_target =~ s/\.{2,}//g;
        $forceboot =~ s/\.{2,}//g;
        # normalize to contain only valid path characters
        # if forceboot contains a path relative to the pxelinux TFTP prefix
        $forceboot_target =~ tr[:/A-Za-z0-9._-][]dc;
        $forceboot =~ tr[:/A-Za-z0-9._-][]dc;

        # try if a file exists for this forceboot target entry
        if ( -r $pxelinuxcfg_path . "/" . $forceboot_target and !-d $pxelinuxcfg_path . "/" . $forceboot_target ) {
            $pxelinux_config_url = "$tftp_url/$forceboot_target";
            $bootinfo            = "force boot from VM config (file)";
        }
        # if no direct file exist, try if we have a mapping for it
        elsif ( my $forceboot_dest = Config( "forceboot", $forceboot_target ) ) {
            $pxelinux_config_url = ( $forceboot_dest =~ m(://) ? "" : $tftp_url . "/" ) . $forceboot_dest;
            $bootinfo = "force boot from LML config";
        }
        # if forceboot is empty
        elsif ( $forceboot_target =~ m(://) ) {
            $pxelinux_config_url = $forceboot_target;
            $bootinfo            = "force boot from VM config (URL)";
        }
        # if the user want to provoke a error
        elsif ( $forceboot_target eq "fatalerror" ) {
            die("Enjoy this fatal error, you called for it.\n");
        }
        # if nothing could be found for the given forceboot entry
        elsif ( Config( "lml", "failoninvalidforceboot" ) ) {
            # Because we have to differ between the old and new variants in forceboot, check if
            # we hit the else block above (a bit ugly, but it works)
            if ( $forceboot_target eq $forceboot ) {
                push( @error, "Invalid force boot target '$forceboot_field'" );
            } else {
                push( @error, "Invalid force boot target in '$forceboot_target_field'" );
            }
        }   # else do nothing to silently ignore invalid force boot targets
    }

    # up till here we have only checks that verify the VM.
    # in case of errors stop processing so that we do not create host records anywhere as long
    # as some conditions are unmet.

    # we only modify something if there are no errors
    if ( not scalar(@error) ) {

        # add lastseen info to host
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN}         = time;
        $LAB->{HOSTS}->{$search_uuid}->{LASTSEEN_DISPLAY} = POSIX::strftime( "%a %b %e %H:%M:%S %Y", localtime );

        # create HOSTS record for DHCP if it has changed (name or networking)
        # ~~ compares array since perl 5.10!!
        #
        # NOTE: This should be after all other pieces of code that compare with the old host name !!!
        if (    not( exists( $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} ) and exists( $LAB->{HOSTS}->{$search_uuid}->{MACS} ) )
             or not $vm_name eq $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME}
             or not @vm_lab_macs ~~@{ $LAB->{HOSTS}->{$search_uuid}->{MACS} } )
        {
            $LAB->{HOSTS}->{$search_uuid}->{HOSTNAME} = $vm_name;
            $LAB->{HOSTS}->{$search_uuid}->{MACS}     = \@vm_lab_macs;
            $has_changed                              = 1;
        }
    }    # no errors in @error

}    # if have $VM

# disconnect from VI
Util::disconnect();

# housekeeping is in tools/lml-maintenance.pl. This script has only the scope of a single VM.

# write dhcp-hosts.conf if it is configured and if we have host entries to write
if ($has_changed) {
    push( @error, UpdateDHCP($LAB) );
}

if ( scalar(@error) ) {

    # have some errors
    print header( -status => "200 Errors: " . join( ", ", @error ), -type => 'text/plain' );
    print join( "\n", @{ Config( "pxelinux", "error_main" ) } ) . "\n";    # multiline values come as array
    print "menu title " . Config( "pxelinux", "error_title" ) . " " . $vm_name . "\n";
    my $c = 1;
    foreach my $e (@error) {
        $e =~ s/\^/^^/g;                                                   # pxelinux menu uses ^ to mark keyboard shortcuts. ^^ comes out as plain ^
        print <<EOF;
label l$c
        menu label $c. $e
EOF
        print join( "\n", @{ Config( "pxelinux", "error_item" ) } ) . "\n";
        $c++;
    }

    # if the VM is found and all is fine then redirect to default PXE configuration
} elsif ($vm_name) {

    # dump $LAB to file only if all is fine. This makes sure that LML stays with the old view of the lab for some kind of
    # hard to catch errors.
    my $labfile = Config( "lml", "datadir" );
    open( LAB_CONF, ">", "$labfile/lab.conf" ) || die "Could not open '$labfile' for writing\n";
    flock( LAB_CONF, 2 ) || die;
    print LAB_CONF "# pxelinux.pl " . POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime() ) . " for $vm_name ($search_uuid)\n";
    print LAB_CONF Data::Dumper->Dump( [$LAB], [qw(LAB)] );
    close(LAB_CONF);

    # these can be set by the force boot handling above
    $pxelinux_config_url = $base_url . "/default" unless ($pxelinux_config_url);
    $bootinfo            = "all is fine"          unless ($bootinfo);
    print header(
                  -status => "302 VM is $vm_name and $bootinfo" . ( $has_changed ? ", some hosts changed" : "" ),
                  -type => 'text/plain',
                  -location => $pxelinux_config_url
    );
} else {

    # if the VM is not found then also give some error text
    if ( Config( "pxelinux", "redirect_unknown_to_default" ) ) {
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
