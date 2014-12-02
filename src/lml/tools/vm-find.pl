#!/usr/bin/perl
#
# give VM name regex as command line argument, default is to find all VMs
# set LML_DEBUG=1 for debug output

use strict;
use warnings;

# end of user configuration

# place DLLs and PMs with the required subdirectory structure into lib/ next to this script
use FindBin;
use lib "$FindBin::Bin/../lib";

use LML::Common;
use LML::Config;
use LML::VMware;

# Check if an value was submitted, else return an default
sub check_value {
    my $value = shift;

    if ( defined $value ) {
        return $value;
    }
    else {
        return "-- NOT SET --";
    }
}

# define the --format option, default is UUID,PATH
my %opts = (
    format => {
                type     => "=s",
                help     => "Output format for found VMs (use %UUID, %PATH, %DISPLAYPATH, %USER, %HOST, %NAME, %EXPIRE, %FORCEBOOT, %FORCEBOOT_TARGET, %STATUS, %BOOTORDER). ",
                required => 0,
                default  => "%UUID%NAME%PATH%STATUS"
    }
);

# parse the options over vmwares module
Opts::add_options(%opts);
Opts::parse();

# get the lml configuration
my $C = new LML::Config();

# display custom fields
if ( my @customfields = keys %{ get_custom_fields() } ) {
    print "Custom Attributes:\n\t" . join( "\n\t", @customfields ) . "\n";
} else {
    print "No Custom Attributes defined - You will not have much fun using LML without them.\n";
}

# display hosts
my $HOSTS = get_hosts();
if (keys %$HOSTS ) {
    printf "\nESX Hosts:\n%-40s%-40s%-40s\n","UUID","NAME","PATH";
    foreach my $host (values %$HOSTS ) {
        printf "%-40s%-40s%-40s\n",$host->{uuid},$host->{name},$host->{path};
    }
    print "\n";
} else {
    print "No ESX Hosts found - You will not have much fun using LML without them.\n";
}

print "Searching for VMs" . "\n";
my $VM = get_all_vm_data( @ARGV ? ( "config.name" => qr($ARGV[0])xi ) : () );
# bail out if no VMs found
die( "No VMs found " . ( @ARGV ? "matching '" . $ARGV[0] . "'  - check your search criteria" : "to work with" ) . " !\n" )
  unless ( scalar( keys %{$VM} ) );

# prepare the output
my $output_format = Opts::get_option('format');
# split the format string (% is delimeter)
my @output_formats = split( /%/, $output_format );
# cut off the first array entry, because its empty
shift @output_formats;

# define the printf format to be used
my $format = ( "%-40s" x @output_formats );

# print the header
print "\n";
printf $format, @output_formats;
print "\n\n";

# get the display filter settings from configuration
my $display_filter_vm_path = $C->get( "gui", "display_filter_vm_path" );

# go over virtual machines and do the job
foreach my $uuid ( keys %{$VM} ) {
    # define the array which will include the content of every column
    my @output;

    # go over the defined output formats
    foreach (@output_formats) {
        # Custom value 'Contact User ID' is mapped to %USER
        if ( $_ eq "USER" ) {
            push @output, check_value( $VM->{$uuid}{CUSTOMFIELDS}->{'Contact User ID'} );
        }
        # Custom value 'EXPIRES' is mapped to %EXPIRE
        elsif ( $_ eq "EXPIRE" ) {
            push @output, check_value( $VM->{$uuid}{CUSTOMFIELDS}->{'Expires'} );
        }
        # Custom value 'Force Boot' is mapped to %FORCEBOOT
        elsif ( $_ eq "FORCEBOOT" ) {
            push @output, check_value( $VM->{$uuid}{CUSTOMFIELDS}->{'Force Boot'} );
        }
        # Custom value 'Force Boot Target' is mapped to %FORCEBOOT_TARGET
        elsif ( $_ eq "FORCEBOOT_TARGET" ) {
            push @output, check_value( $VM->{$uuid}{CUSTOMFIELDS}->{'Force Boot Target'} );
        }
        # Raw path
        elsif ( $_ eq "PATH" ) {
            push @output, $VM->{$uuid}{PATH};
        }
        # Use the display regex for vm paths if there is one
        elsif ( $_ eq "DISPLAYPATH" ) {
            my $display_vm_path = $VM->{$uuid}{PATH};
            if ($display_filter_vm_path) {
                $display_vm_path =~ s/$display_filter_vm_path/$1/x;
            }
            push @output, $display_vm_path;
        }
        # Is the VM powered on or off
        elsif ( $_ eq "STATUS" ) {
            push @output, $VM->{$uuid}{POWERSTATE};
        }
        elsif ( $_ eq "BOOTORDER" ) {
            push @output, join(",",@{$VM->{$uuid}{BOOTORDER}});
        }
        # Just push the hash value to output array
        else {
            push @output, $VM->{$uuid}{$_};
        }
    }

    # print the determined output in one line
    printf $format . "\n", @output;
}

print "\n";
printf "Found %d VMs\n", scalar( keys %{$VM} );
Debug( Data::Dumper->Dump( [$VM], [qw(VM)] ) );
