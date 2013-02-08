package LML::Common;

use strict;
use Exporter;
use vars qw(
  @ISA
  @EXPORT
);
our @ISA    = qw(Exporter);
our @EXPORT = qw(%CONFIG @CONFIGFILES Config ReadDataFile $isDebug Debug $LML_VERSION);

use FindBin;

# Defaults for Data Dumper
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;    #Sort the keys in the output
$Data::Dumper::Deepcopy = 1;    #Enable deep copies of structures
$Data::Dumper::Indent   = 2;    #Output in a reasonable style (but no array indexes)
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
#use DateTime::Format::Flexible;
use Config::IniFiles;

use POSIX;

# our version, patched by Makefile
our $LML_VERSION = "DEVELOPMENT_LML_VERSION";

# debugging
our $isDebug = defined( $ENV{LML_DEBUG} );

sub Debug {
    print STDERR "DEBUG: " . join( "\nDEBUG: ", @_ ) . "\n" if ($isDebug);
}
Debug("Our \@INC list looks like this:");
Debug(@INC);

# open main config file case-insensitive
our %CONFIG;
my $conf;
unless ( $ENV{HOME} ) {
    # set HOME from NSS if not set to prevent Perl error in next line
    $ENV{HOME} = ( getpwuid($>) )[7];
    Debug("Set HOME to $ENV{HOME}");
}

# here we rely on the fact that @INC contains our private lib dir in the first place.
our @CONFIGFILES = map( realpath($_), <{$INC[0]/../default.conf,/etc/lml/*.conf,$ENV{HOME}/.lml-*.conf}> );
Debug( "Our config files are: ", join( " ", @CONFIGFILES ) );
foreach my $f (@CONFIGFILES) {
    $conf = new Config::IniFiles(
                                  -file   => $f,
                                  -nocase => 1,
                                  -import => $conf
    ) or die "Could not read '$f'";
    if ($isDebug) {
        Debug("Read from $f:");
        $conf->OutputConfigToFileHandle( *STDERR, 1 );
    }
}

if ($isDebug) {
    Debug("Merged configuration:");
    $conf->OutputConfigToFileHandle(*STDERR);
}

tie %CONFIG, 'Config::IniFiles', ( -import => $conf, -nocase => 1 ) or die "Could not tie to config.";

sub Config($$) {
    my $section = shift;
    my $key = shift;
    if (exists($CONFIG{$section}{$key})) {
        return $CONFIG{$section}{$key};
    } else {
        return undef;
    }
}

# some config checks
die "Missing or invalid LML.DATADIR (".Config("lml","datadir").") from configuration\n" unless ( -d Config("lml","datadir") );

# setup vSphere environment
die "Missing VSPHERE configuration section in configuration\n" unless ( $CONFIG{vsphere} );
$ENV{VI_USERNAME}                  = Config("vsphere","username")        if ( Config("vsphere","username") );
$ENV{VI_PASSWORD}                  = Config("vsphere","password")        if ( Config("vsphere","password") );
$ENV{VI_SERVER}                    = Config("vsphere","server")          if ( Config("vsphere","server") );
$ENV{VI_PASSTHROUGHAUTH}           = Config("vsphere","passthroughauth") if ( Config("vsphere","passthroughauth") );
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0                                 if ( Config("vsphere","disablecertificatevalidation") );

# read data file
# $1 is file in data dir
# $2 is hashref to work on - must match the one used in the data file
# NOTE: THIS DOES NOT YET WORK, NEED TO MAKE SURE THAT THE HASHREF IS CALLED THE SAME AS IN THE DATA FILE. OR MIGRATE TO JSON STORAGE...
sub ReadDataFile($%) {
    my $datafile = Config( "lml", "datadir" ) . "/" . shift;
    my $hashref = shift;
	if ( -r $datafile ) {
	    local $/ = undef;
	    open( DATAFILE, "<", $datafile ) || die "Could not open $datafile for reading.\n";
	    flock( DATAFILE, 1 ) || die;
	    binmode DATAFILE;
	    eval <DATAFILE> || die "Could not parse $datafile:\n$@\n";
	    close(DATAFILE);
	}
}
1;
