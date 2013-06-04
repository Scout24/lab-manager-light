#!/usr/bin/perl

use strict;
use warnings;

use CGI ':standard';

sub get_parameter_hash {
    # define the paramter hash to be filled
    my %parameter;

    # go through each paramter name and access its value
    for my $name ( param() ) {
        $parameter{$name} = param($name);
    }

    # return the generated paramter hash
    return %parameter;
}

sub read_file {
    # get the absolute path of the file to be proxied
    my $filename = shift;
    my @lines;

    # open the file
    open( PROXY_FILE, "<", $filename )
      or die "Could not open '" . $filename . "' for writing: $!\n";

    # get all lines
    @lines = <PROXY_FILE>;

    # close the file
    close(PROXY_FILE);

    # retrun the array containing the lines
    return @lines;
}

# create an hash of the submitted params
my %parameter = get_parameter_hash();

print header( -status => '200 Proxy mode' );

# if we have an file to proxy, do it
if ( defined $parameter{'filename'} ) {
    my $filename = $ENV{DOCUMENT_ROOT} . $parameter{'filename'};

    # go through each line of the file
    foreach ( read_file( $filename ) ) {
        print "DEBUG: " . $_;
    }
}

