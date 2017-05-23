package LML::Common;

use strict;
use warnings;
use Exporter;
use vars qw(
  @ISA
  @EXPORT
);
our @ISA    = qw(Exporter);
our @EXPORT = qw(%CONFIG @CONFIGFILES LoadConfig Config $isDebug Debug $LML_VERSION get_token_replacement);

use FindBin;

# Defaults for Data Dumper
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;    # Sort the keys in the output
$Data::Dumper::Deepcopy = 1;    # Enable deep copies of structures
$Data::Dumper::Indent   = 2;    # Output in a reasonable style (but no array indexes)
$Data::Dumper::Useqq    = 1;    # use double quoted strings with "\n" escapes
$Data::Dumper::Purity   = 1;    # extra code for correct perl representation

use Fcntl 'SEEK_SET';
use File::Path;
use File::Find;
use File::Basename;
use File::Glob ':glob';
use IO::Handle;
use Path::Class 'dir';
use Cwd 'realpath';
use Config::IniFiles;

use POSIX;

# our version, patched by Makefile
our $LML_VERSION = "DEVELOPMENT_LML_VERSION";

# debugging
our $isDebug = (defined( $ENV{LML_DEBUG} ) and $ENV{LML_DEBUG});

sub Debug {
    print STDERR "DEBUG: " . join( "\nDEBUG: ", @_ ) . "\n" if ($isDebug);
}
Debug("Our \@INC list looks like this:",@INC);

my $has_io_socket_ssl = eval {
    # if IO::Socket:SSL is available force vSphere SDK to use it
    require IO::Socket::SSL;
    # This overrides a wrong settings in the vSphere SDK VICommon.pm, see Net::HTTPS documentation
    $Net::HTTPS::SSL_SOCKET_CLASS="IO::Socket::SSL";
    Debug("Forcing SDK to use IO::Socket:SSL");
    return 1;
};
if ($@) {
    # without IO::Socket::SSL LWP will use Net::SSL which does not support SSL verification
    # therefore we MUST disable SSL verification in this case.
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    Debug("SDK uses Net::SSL, disabling SSL verification");
}


our @CONFIGFILES;
our %CONFIG;

sub LoadConfig {

    # optionally specify config files to read
    if ( scalar(@_) ) {
        @CONFIGFILES = @_;
    }

    # or use built-in default list
    else {
        unless ( $ENV{HOME} ) {

            # set HOME from NSS if not set
            $ENV{HOME} = ( getpwuid($>) )[7];
            Debug("Set HOME to $ENV{HOME}");
        }
        @CONFIGFILES = map( realpath($_), <{$INC[0]/../default.conf,/etc/lml/*.conf,$ENV{HOME}/.lml-*.conf}> );
    }

    # open main config file case-insensitive

    my $conf;

    Debug( "Our config files are: ", join( " ", @CONFIGFILES ) );
    foreach my $f (@CONFIGFILES) {
        $conf = new Config::IniFiles(
                                      -file   => $f,
                                      -nocase => 1,
                                      -import => $conf
        ) or die "Could not read '$f'\n";
        if ($isDebug) {
            Debug("Read from $f:");
            $conf->OutputConfigToFileHandle( *STDERR, 1 ) if ($isDebug);
        }
    }

    tie %CONFIG, 'Config::IniFiles', ( -import => $conf, -nocase => 1 ) or die "Could not tie to config.";

    $isDebug = 1 if ( Config( "lml", "debug" ) );
    if ($isDebug) {
        Debug("Merged configuration:");
        $conf->OutputConfigToFileHandle(*STDERR);
    }

    # some config checks
    die "Missing or invalid LML.DATADIR (" . Config( "lml", "datadir" ) . ") from configuration\n" unless ( -d Config( "lml", "datadir" ) );

    # setup vSphere environment
    die "Missing VSPHERE configuration section in configuration\n" unless ( $CONFIG{vsphere} );
    $ENV{VI_USERNAME}        = Config( "vsphere", "username" )        if ( Config( "vsphere", "username" ) );
    $ENV{VI_PASSWORD}        = Config( "vsphere", "password" )        if ( Config( "vsphere", "password" ) );
    $ENV{VI_SERVER}          = Config( "vsphere", "server" )          if ( Config( "vsphere", "server" ) );
    $ENV{VI_PASSTHROUGHAUTH} = Config( "vsphere", "passthroughauth" ) if ( Config( "vsphere", "passthroughauth" ) );
    if ($has_io_socket_ssl) {
        # SSL verification is only possible in IO::Socket::SSL
        IO::Socket::SSL::set_client_defaults(SSL_verify_mode => $IO::Socket::SSL::SSL_VERIFY_NONE) if ( Config( "vsphere", "disablecertificatevalidation" ) );
    }
    if ( Config ("lml","disableproxy") ) {
        delete $ENV{HTTPS_PROXY};
        delete $ENV{HTTP_PROXY};
        delete $ENV{http_proxy};
        delete $ENV{https_proxy};
    }

    return %CONFIG;
}

sub Config($$) {
    my $section = shift;
    my $key     = shift;
    if ( exists( $CONFIG{$section}{$key} ) ) {
        return $CONFIG{$section}{$key};
    } else {
        return undef;
    }
}

sub get_token_replacement {
    my ( $match, $tokens ) = @_;    # match is %%%token%%%, $tokens is hashref to tokens
    my $token = lc( substr( $match, 3, -3 ) );
    return defined $tokens->{$token} ? $tokens->{$token} : "!!!NO_TOKEN_$token!!!";

}
1;
