package LML::Common;

use strict;
use warnings;
use Exporter;
use vars qw(
  @ISA
  @EXPORT
);
our @ISA    = qw(Exporter);
our @EXPORT = qw(%CONFIG @CONFIGFILES LoadConfig Config $isDebug Debug $LML_VERSION);

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
use DateTime::Format::Flexible;
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
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0 if ( Config( "vsphere", "disablecertificatevalidation" ) );
    if ( Config ("lml","disableproxy") ) {
        $ENV{HTTPS_PROXY} = $ENV{HTTP_PROXY} = $ENV{http_proxy} = $ENV{https_proxy} = "";
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

1;
