#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

use lib "/usr/lib/lml/lib";

use LML::Config;
use LML::VMware;
use LML::Common;

my $start = undef;
my $stop  = undef;
my $help  = undef;

sub print_help {
    print "vm-cmd.pl [OPTION] [UUID]\n\n";
    print "   --start \t Start the given VM\n";
    print "   --stop  \t Stop the given VM gracefully\n";
    print "   --help  \t Show this\n\n";

    exit;
}

sub perform_poweron {
    my $uuid = shift;
    get_vi_connection();

    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []
    );

    if ($vm_view) {
        eval { $vm_view->PowerOnVM(); };

        if ($@) {
            Debug("SDK PowerOnVM command exited abnormally");
            return 1;
        }
    }
    else {
        Debug("Could not retrieve vm view for uuid $uuid");
        return 0;
    }
}

sub perform_shutdown {
    my $uuid = shift;
    get_vi_connection();

    my $vm_view = Vim::find_entity_view(
                                         view_type  => 'VirtualMachine',
                                         filter     => { "config.uuid" => $uuid },
                                         properties => []
    );

    if ($vm_view) {
        eval { $vm_view->ShutdownGuest(); };

        if ($@) {
            Debug("SDK ShutdownGuest command exited abnormally");
            return 1;
        }
    }
    else {
        Debug("Could not retrieve vm view for uuid $uuid");
        return 0;
    }
}

GetOptions(
            "start" => \$start,
            "stop"  => \$stop,
            "help"  => \$help,
);

print_help() if defined $help;

my $C = new LML::Config();

if ( defined $start and defined $stop ) {
    die("The options --start and --stop cannot be used at the same time! Stop ...");
}

if ($start) {
    perform_poweron($ARGV[0]);

}
elsif ($stop) {
    perform_shutdown($ARGV[0]);
}
