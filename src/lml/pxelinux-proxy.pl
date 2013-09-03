#!/usr/bin/perl

# all URL parameters are tokens that will be replaced
# filename URL param gives filename, relative to docroot, to read
# token format in file is %%%token%%%, case-insensitive
#

use strict;
use warnings;
use File::Slurp;

use CGI ':standard';

use FindBin;
use lib "$FindBin::Bin/lib";

use LML::TokenReplacer;

sub get_parameters {
    # define the paramter hash to be filled
    my %parameters = map { lc($_) => param($_) } param();
    return \%parameters;
}

# create an hash of the submitted params
my $parameters = get_parameters();

# if we have an file to proxy, do it
if ( defined $parameters->{'filename'} ) {
    if ( $parameters->{'filename'} =~ m(\.\.) ) {
        print header( -status => "500 Relative filename forbidden" ) . start_html . h1("Relative filename forbidden") . end_html;
    }
    else {
        # IMPORTANT: DocumentRoot infront to prevent the reading of outside files
        my $filename = $ENV{DOCUMENT_ROOT} . $parameters->{filename};
        delete $parameters->{filename};    # remove filename from parameter list
        Delete("filename");                # remove filename from CGI query params
        my $query_string = query_string(); # keep query string without filename to append to some stuff.
        my $tr = new LML::TokenReplacer($parameters);
        if ( -f $filename ) {
            # print out the header with OK status
            print header( -status => '200 Proxy mode' );
            my $data = $tr->replace(scalar read_file($filename));
            $data =~ s(
                \s+             # separator to start
                .+?\.pxelinux   # non-greedy something that ends on .pxelinux
            )($&?$query_string)xg;    # m makes ^ match also after newlines in the middle of $data
            print $data;
        }
        else {
            # print out the header with 404 status
            print header( -status => '404 File not found' ) . start_html . h1("File $filename not found") . end_html;
        }
    }
}

1;
