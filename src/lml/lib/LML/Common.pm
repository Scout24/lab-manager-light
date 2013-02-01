package LML::Common;

use strict;
use Exporter;
use vars qw(
            @ISA
            @EXPORT
          );
our @ISA         = qw(Exporter);
our @EXPORT     = qw(%CONFIG @CONFIGFILES $isDebug Debug $LML_VERSION);

use FindBin;


# Defaults for Data Dumper
use Data::Dumper;
$Data::Dumper::Sortkeys = 1; #Sort the keys in the output
$Data::Dumper::Deepcopy = 1; #Enable deep copies of structures
$Data::Dumper::Indent = 2; #Output in a reasonable style (but no array indexes)
$Data::Dumper::Useqq  = 1;  # use double quoted strings with "\n" escapes
$Data::Dumper::Purity = 1;  # extra code for correct perl representation


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
our $LML_VERSION="DEVELOPMENT_LML_VERSION";

# debugging
our $isDebug = defined($ENV{LML_DEBUG});
sub Debug {
	print STDERR "DEBUG: ".join("\nDEBUG: ",@_)."\n" if ($isDebug);
}
Debug("Our \@INC list looks like this:");
Debug(@INC);
# open main config file case-insensitive 
our %CONFIG;
my $conf;
unless ($ENV{HOME}) {
	# set HOME from NSS if not set to prevent Perl error in next line
	$ENV{HOME} = (getpwuid($>))[7];
	Debug("Set HOME to $ENV{HOME}");
}
# here we rely on the fact that @INC contains our private lib dir in the first place.
our @CONFIGFILES=map(realpath($_),<{$INC[0]/../default.conf,/etc/lml/*.conf,$ENV{HOME}/.lml-*.conf}>);
Debug("Our config files are: ",join(" ",@CONFIGFILES));
foreach my $f (@CONFIGFILES) {
	$conf = new Config::IniFiles(	-file=>$f,
					-nocase=>1,
					-import=>$conf
					) or die "Could not read '$f'";
	if ($isDebug) {
		Debug("Read from $f:");
		$conf->OutputConfigToFileHandle(*STDERR, 1);
	}
}

if ($isDebug) {
	Debug("Merged configuration:");
	$conf->OutputConfigToFileHandle(*STDERR);
}

tie %CONFIG, 'Config::IniFiles', (-import=>$conf,-nocase=>1) or die "Could not tie to config.";

# some config checks
die "Missing or invalid LML.DATADIR ($CONFIG{lml}{datadir}) from configuration\n" unless (-d $CONFIG{lml}{datadir});

# setup vSphere environment
die "Missing VSPHERE configuration section in configuration\n" unless ($CONFIG{vsphere});
$ENV{VI_USERNAME}=$CONFIG{vsphere}{username} if ($CONFIG{vsphere}{username});
$ENV{VI_PASSWORD}=$CONFIG{vsphere}{password} if ($CONFIG{vsphere}{password});
$ENV{VI_SERVER}=$CONFIG{vsphere}{server} if ($CONFIG{vsphere}{server});
$ENV{VI_PASSTHROUGHAUTH}=$CONFIG{vsphere}{passthroughauth} if ($CONFIG{vsphere}{passthroughauth});
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0 if ($CONFIG{vsphere}{disablecertificatevalidation});

1;
