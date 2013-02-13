use strict;
use warnings;

package LML::DHCP;

use strict;
use Exporter;
use vars qw(
  $VERSION
  @ISA
  @EXPORT
);
our $VERSION = 1.00;
our @ISA     = qw(Exporter);
our @EXPORT  = qw(UpdateDHCP);

use LML::Common;

# write out all host entries in $LAB->HOSTS into the dhcp hosts file
sub UpdateDHCP($) {
    my ($LAB) = @_;

    my @error = ();
    if ( my $dhcpconf = Config( "dhcp", "hostsfile" ) ) {
        my $dhcp_hosts = "";
        for my $u ( keys( %{ $LAB->{HOSTS} } ) ) {
            my $count = 0;
            if ( exists( $LAB->{HOSTS}->{$u}->{MACS} ) ) {
                for my $m ( sort( @{ $LAB->{HOSTS}->{$u}->{MACS} } ) ) {
                    $dhcp_hosts .= "host $u" . ( $count > 0 ? "-$count" : "" ) . " { \n";
                    $dhcp_hosts .= "\thardware ethernet $m;\n";
                    my $hostname = $LAB->{HOSTS}->{$u}->{HOSTNAME} . ( $count > 0 ? "-$count" : "" );
                    $dhcp_hosts .= "\toption host-name \"$hostname" . ( Config( "dhcp", "appenddomain" ) ? "." . Config( "dhcp", "appenddomain" ) : "" ) . "\";\n";

                    # the following forces the dhcpd to update the DNS records even if the client did NOT send a hostname!!!
                    # took me full day to figure that out :-(
                    $dhcp_hosts .= "\tddns-hostname \"$hostname\";\n";
                    $dhcp_hosts .= "\tfixed-address $LAB->{HOSTS}->{$u}->{IP};\n" if ( exists( $LAB->{HOSTS}->{$u}->{IP} ) );
                    if ( exists( $LAB->{HOSTS}->{$u}->{EXTRAOPTS} ) ) {
                        my $extraopts = $LAB->{HOSTS}->{$u}->{EXTRAOPTS};
                        $extraopts =~ s(;*$)(;);       # add trailing ; if it is missing, found in http://stackoverflow.com/questions/9353836/perl-regex-meant-to-add-trailing-slash-if-there-is-none-doubles-existing-slash
                        $extraopts =~ s(;(.+))(;\n\t$1)g;    # if there are several options separated by ; then break them into several lines
                        $dhcp_hosts .= "\t" . $extraopts . "\n";
                    }
                    $dhcp_hosts .= "}\n\n";
                    $count++;
                }
            } else {
                warn "VERY STRANGE: No MACs found for VM " . $LAB->{HOSTS}->{$u}->{HOSTNAME} . " ($u)\n";
                warn Data::Dumper->Dump( [ $LAB->{HOSTS}->{$u} ], [qw(LAB_HOSTS_uuid)] );
                warn "Please try to found out how this VM could PXE boot off LML without having a NIC in the managed network :-)\n";
            }
        }
        open( DHCP_HOSTS, ">", $dhcpconf ) or die "Could not open '$dhcpconf' for writing: $!\n";
        flock( DHCP_HOSTS, 2 ) || die;
        print DHCP_HOSTS $dhcp_hosts or die "Could not write to '$dhcpconf': $!\n";
        close(DHCP_HOSTS);

        # reload dhcp server
        my $dhcp_triggercommand = Config( "dhcp", "triggercommand" );
        if ($dhcp_triggercommand) {
            my $result = qx($dhcp_triggercommand 2>&1);
            Debug("dhcp triggercommand '$dhcp_triggercommand' said:\n$result") if ($isDebug);
            if ( $? > 0 ) {
                warn "trigger command '$dhcp_triggercommand' failed:\n$result";
                push( @error, "Could not trigger DHCP server, please call for help" );

                # FIXME: Rollback last change or something
            }
        }
    }
    return @error;
}

1;
