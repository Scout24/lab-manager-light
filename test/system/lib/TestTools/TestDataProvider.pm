package TestTools::TestDataProvider;

use strict;
use warnings;

use Config::IniFiles;
use Data::Dumper;

# debugging
our $isDebug = ( defined( $ENV{LML_DEBUG} ) and $ENV{LML_DEBUG} );

sub parseTestData {
    my $cfg;
    my @test_data = ();

    unless ( $ENV{HOME} ) {
        # set HOME from NSS if not set
        $ENV{HOME} = ( getpwuid($>) )[7];
        Debug("Set HOME to $ENV{HOME}");
    }

    my $test_config_file = -r 'lml-system-test.ini' ? 'lml-system-test.ini' : $ENV{HOME} . "/.lml-system-test.ini";
    if ( -r $test_config_file ) {
        Debug("Using test config file $test_config_file");
        $cfg = Config::IniFiles->new( -file => $test_config_file, -default => "defaults" );
    }
    else {
        print STDERR "Neither lml-system-test.ini nor ~/.lml-system-test.ini could be found.\n";
        exit 1;
    }

    foreach my $section ( $cfg->Sections() ) {
        if ( "defaults" ne $section ) {
            # Generate a hash which contains our test specs
            my %test_spec = (
                              label             => $section,
                              boot_timeout      => $cfg->val( $section, 'boot_timeout', 0 ),
                              test_host         => $cfg->val( $section, 'test_host', 0 ),
                              vm_name_prefix    => $cfg->val( $section, 'vm_name_prefix', 0 ),
                              username          => $cfg->val( $section, 'username', 0 ),
                              folder            => $cfg->val( $section, 'folder', 0 ),
                              lmlhostpattern    => $cfg->val( $section, 'lmlhostpattern', 0 ),
                              force_network     => $cfg->val( $section, 'force_network', 0 ),
                              force_boot_target => $cfg->val( $section, 'force_boot_target', 0 ),
                              result            => $cfg->val( $section, 'result', 0 ),
                              expect            => [ get_array( $cfg, $section, 'expect' ) ],
            );

            # Add an esx host, if defined in configuration
            my $esx_host = $cfg->val( $section, 'esx_host', undef );
            $test_spec{esx_host} = $esx_host if defined $esx_host;

            # Add the generated hash to our test data
            push @test_data, \%test_spec;
        }
    }
    return @test_data;
}

sub Debug {
    print STDERR "DEBUG: " . join( "\nDEBUG: ", @_ ) . "\n" if ($isDebug);
}

sub get_array {
    # return list, even if only single item
    my ( $cfg, $section, $key ) = @_;
    # config sections and keys are always lowercase.
    $section = $section;
    $key     = $key;
    my @raw_value = ();
    if ( defined( $cfg->val( $section, $key ) ) ) {
        @raw_value = ref( $cfg->val( $section, $key ) ) eq "ARRAY" ? @{ $cfg->val( $section, $key ) } : ( $cfg->val( $section, $key ) );
    }
    Debug( "TestDataProvider->get_array($section,$key) at " . ( caller(0) )[1] . ":" . ( caller(0) )[2] . " = " . join( ", ", @raw_value ? @raw_value : ("<empty array>") ) );
    return @raw_value;
}

my @testData = parseTestData();

Debug( "Parsed test spec:\n" . Data::Dumper->Dump( [ \@testData ], ["testData"] ) );

1;
