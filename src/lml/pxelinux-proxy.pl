#!/usr/bin/perl

# all URL parameters are tokens that will be replaced
# token format in file is %%%token%%%, case-insensitive
#
# TODO: use token replacement library and harden script against exploits
#
use strict;
use warnings;

use CGI ':standard';

sub get_parameter_hash {
    # define the paramter hash to be filled
    my %parameter;

    # go through each paramter name and access its value
    for my $name ( param() ) {
        $parameter{lc($name)} = param($name);
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

sub replace_token {
    my $line = shift;
    my $parameter = shift;

    # do we have a token
    if ( $line =~ /\%\%\%([a-zA-Z\d_]+)\%\%\%/ ) {
        my $token = $1;

        # is the token existent in our parameter
        if ( defined ( $$parameter{lc($token)} ) ) {
            $line =~ s/\%\%\%$token\%\%\%/$$parameter{lc($token)}/i;
            # ok first token is replaced, play the game again
            replace_token($line, $parameter);
        } else {
            # set NO_TOKEN_X for better debugging
            $line =~ s/\%\%\%$token\%\%\%/!!!NO_TOKEN_$token!!!/i;
            replace_token($line, $parameter);
        }
    } else {
        return $line;
    }
}

# create an hash of the submitted params
my %parameter = get_parameter_hash();

# if we have an file to proxy, do it
if ( defined $parameter{'filename'} ) {
    # IMPORTANT: DocumentRoot infront to prevent the reading of outside files
    my $filename = $ENV{DOCUMENT_ROOT} . $parameter{'filename'};

    # go through each line of the file
    if ( -f $filename ) {
        # get the query string and filter out the filename option
        my $query_string = $ENV{QUERY_STRING};
        $query_string =~ s/(.*)filename=[^&]+&*(.*)/$1$2/;
        # print out the header with OK status
        print header( -status => '200 Proxy mode' );
        foreach ( read_file( $filename ) ) {
            my $line = $_;
            # only trigger on config or append lines
            $line =~ s/^(\s*(?:(?:config)|(?:append)|(?:include)).*\.pxelinux)/$1\?$query_string/g;
            print replace_token($line, \%parameter);
        }

    } else {
        # print out the header with 404 status
        print header( -status => '404 File not found' );
    }
}

