package LML::Common;

use strict;
use Exporter;
use vars qw(
            $VERSION
            @ISA
            @EXPORT
          );
our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT     = qw(%CONFIG);

use FindBin;
use lib "$FindBin::RealBin/../../lib";


# Defaults for Data Dumper
use Data::Dumper;
$Data::Dumper::Sortkeys = 1; #Sort the keys in the output
$Data::Dumper::Deepcopy = 1; #Enable deep copies of structures
$Data::Dumper::Indent = 2; #Output in a reasonable style (but no array indexes)
$Data::Dumper::Useqq  = 1;  # use double quoted strings with "\n" escapes
$Data::Dumper::Purity = 1;  # extra code for correct perl representation


# use VMware VI Perl SDK included modules
use Fcntl 'SEEK_SET';
use File::Path;
use File::Find;
use File::Basename;
use File::Glob ':glob';
use IO::Handle;
use Path::Class 'dir';
use Cwd;

use DateTime::Format::Flexible;

use Config::IniFiles;

# open main config file case-insensitive 
our %CONFIG;
tie %CONFIG, 'Config::IniFiles', (-file=>"/etc/lml.conf",-nocase=>1) or die "Could not open '/etc/lml.conf'";

# some config checks
die "Missing or invalid LML.DATADIR from configuration" unless (-d $CONFIG{lml}{datadir});

# setup vSphere environment
die "Missing VSPHERE configuration section in configuration" unless ($CONFIG{vsphere});
$ENV{VI_USERNAME}=$CONFIG{vsphere}{username} if ($CONFIG{vsphere}{username});
$ENV{VI_PASSWORD}=$CONFIG{vsphere}{password} if ($CONFIG{vsphere}{password});
$ENV{VI_SERVER}=$CONFIG{vsphere}{server} if ($CONFIG{vsphere}{server});
$ENV{VI_PASSTHROUGHAUTH}=$CONFIG{vsphere}{passthroughauth} if ($CONFIG{vsphere}{passthroughauth});

1;
