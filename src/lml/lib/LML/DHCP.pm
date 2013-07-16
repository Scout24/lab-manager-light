use strict;
use warnings;

package LML::DHCP;

use LML::Config;
use LML::Common;

use Carp;

# write out all host entries in $LAB->HOSTS into the dhcp hosts file
sub UpdateDHCP {
    my ( $C, $LAB ) = @_;

    croak( "1st arg must be LML::Config object and not " . ref($C) . " in " . ( caller(0) )[3] )
      unless ( ref($C) eq "LML::Config" );
    croak( "2nd arg must be LML::Lab object and not " . ref($LAB) . " in " . ( caller(0) )[3] )
      unless ( ref($LAB) eq "LML::Lab" );

    my @error = ();
    if ( my $dhcpconf = $C->get( "dhcp", "hostsfile" ) ) {
        my $dhcp_hosts = "";
        my $default_appenddomain = $C->appenddomain;
        for my $u ( keys( %{ $LAB->{HOSTS} } ) ) {
            my $count = 0;
            if ( exists( $LAB->{HOSTS}->{$u}->{MACS} ) ) {
                for my $m ( sort( @{ $LAB->{HOSTS}->{$u}->{MACS} } ) ) {
                    $dhcp_hosts .= "host $u" . ( $count > 0 ? "-$count" : "" ) . " { \n";
                    $dhcp_hosts .= "\thardware ethernet $m;\n";
                    my $hostname = $LAB->{HOSTS}->{$u}->{HOSTNAME} . ( $count > 0 ? "-$count" : "" );
                    Debug(Data::Dumper->Dump([$LAB->{HOSTS}->{$u}],["LAB->{HOSTS}->{$u}"]));
                    $dhcp_hosts .= "\toption host-name \"$hostname"
                      . "." . (defined($LAB->{HOSTS}->{$u}->{DNS_DOMAIN}) ? $LAB->{HOSTS}->{$u}->{DNS_DOMAIN} : $default_appenddomain) . "\";\n";

                # the following forces the dhcpd to update the DNS records even if the client did NOT send a hostname!!!
                # took me full day to figure that out :-(
                    $dhcp_hosts .= "\tddns-hostname \"$hostname\";\n";
                    $dhcp_hosts .= "\tfixed-address $LAB->{HOSTS}->{$u}->{IP};\n"
                      if ( exists( $LAB->{HOSTS}->{$u}->{IP} ) );
                    if ( exists( $LAB->{HOSTS}->{$u}->{EXTRAOPTS} ) ) {
                        my $extraopts = $LAB->{HOSTS}->{$u}->{EXTRAOPTS};
                        $extraopts =~ s(;*$)(;)
                          ; # add trailing ; if it is missing, found in http://stackoverflow.com/questions/9353836/perl-regex-meant-to-add-trailing-slash-if-there-is-none-doubles-existing-slash
                        $extraopts =~ s(;(.+))(;\n\t$1)g
                          ;    # if there are several options separated by ; then break them into several lines
                        $dhcp_hosts .= "\t" . $extraopts . "\n";
                    }
                    $dhcp_hosts .= "}\n\n";
                    $count++;
                }
            } else {
                carp "VERY STRANGE: No MACs found for VM "
                  . $LAB->{HOSTS}->{$u}->{HOSTNAME}
                  . " ($u)\n"
                  . Data::Dumper->Dump( [ $LAB->{HOSTS}->{$u} ], [qw(LAB_HOSTS_uuid)] )
                  . "Please try to find out how this VM could PXE boot from LML without having a NIC in the managed network :-)\n"
                  ;
            }
        }
        open( DHCP_HOSTS, ">", $dhcpconf ) or die "Could not open '$dhcpconf' for writing: $!\n";
        flock( DHCP_HOSTS, 2 ) || die;
        print DHCP_HOSTS $dhcp_hosts or die "Could not write to '$dhcpconf': $!\n";
        close(DHCP_HOSTS);

        # reload dhcp server
        my $dhcp_triggercommand = $C->get( "dhcp", "triggercommand" );
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
