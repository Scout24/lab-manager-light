use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Config;
use LML::Lab;
#use Test::Mock::LWP::Dispatch;
use LWP::Simple qw(!head get);
use CGI qw(:standard);    # then only CGI.pm defines a head()

BEGIN {
    use_ok "LML::VMcreate::VMproperties";
}

#######################
# test setup
#######################

my $C = new LML::Config( {
       vsphere => {
           expires_european       => 1,
           datacenter             => "some datacenter",
           contactuserid_field    => "Contact User ID",
           expires_field          => "Expires",
           forceboot_field        => "Force Boot",
           forceboot_target_field => "Force Boot Target",

       },
       hostrules => { pattern => '^[a-z]{6}[0-9]{2}$' },
       vm_spec   => {
                    host_announcement => 'some_host_announcement_url',
                    host_spec         => 'some_host_spec_url'
       }
} );

my $lab = new LML::Lab({
    "DATASTORES" => {
        "datastore1" => {
            "id"   => "datastore1",
            "name" => "esx.id1:datastore1",
        }
    },
    "ESXHOSTS" => {
        "id1" => {
            "id"   => "id1",
            "name" => "id1.some.domain"
        },
        "id2" => {
            "id"   => "id2",
            "name" => "id2.some.domain"
        }
    }
});

my $expected_diskSize   = 16384000;
my $expected_memorySize = 2048;
my $expected_number_cpu = 1;

# MOCK: load json vm spec
my $module = new Test::MockModule('LWP::Simple');
$module->mock(
    'get',
    sub {
        return '{"virtualMachine" : {
                "name" : "foo",
                "diskSize"  : ' . $expected_diskSize . ',
                "memory" : ' . $expected_memorySize . ',
                "numberOfProcessors" : ' . $expected_number_cpu . ',
                "hasFrontend" : 0,
                "targetFolder" : "do not care"
            }
        }';
    } );

#######################
# test cases
#######################

# in this test case the esx_host is given (no automatic placement)
{
    my $vm_properties = new_ok(
        "LML::VMcreate::VMproperties" => [
            $C, $lab,
            {
                name       => "devxxx02",
                expiration => "31.12.2019",
                username   => "testuser",
                esx_host   => "esx_server.some.domain",
                folder     => "some folder",
            }
        ]
    );

    my @vms = $vm_properties->generate_vms_array();
    is_deeply(
        \@vms,
        [{
            "custom_fields" => {
                "Contact User ID"   => "testuser",
                "Expires"           => "31.12.2019",
                "Force Boot"        => "ON",
                "Force Boot Target" => "default"
            },
            "datacenter"    => "some datacenter",
            "datastore"     => "esx_server:datastore1",
            "disksize"      => $expected_diskSize,
            "force_network" => undef,
            "guestid"       => "rhel6_64Guest",
            "memory"        => $expected_memorySize,
            "num_cpus"      => $expected_number_cpu,
            "target_folder" => "some folder",
            "vmhost"        => "esx_server.some.domain",
            "vmname"        => "devxxx02"
        }],
        "should create vms_array with expected values"
    );
}

# in this test case the esx_host is not given like called by cli - an
# automatic placement is expected
{
    # there're two test cases for esx_host was not given by cli
    # or has the value "auto_placement" when called by web form
    foreach my $esx_host ( ( undef, "auto_placement" ) ) {

        my $vm_properties = new_ok(
            "LML::VMcreate::VMproperties" => [
                $C, $lab,
                {
                    name       => "devxxx02",
                    expiration => "31.12.2019",
                    username   => "testuser",
                    folder     => "some folder",
                    esx_host   => $esx_host,
                }
            ]
        );

        # THIS IS A UNIT TEST SO WE HAVE TO MOCK COLABORATORS -> required
        # network labels 'network_label_1', 'network_label_2'
        my $mock_vm_networks = new Test::MockModule('LML::VMnetworks');
        $mock_vm_networks->mock(
            'find_network_labels',
            sub {
                my ( $self, $vm_name, $force_network ) = @_;
                return ( 'network_label_1', 'network_label_2' ) if ( $vm_name eq 'devxxx02' && !defined($force_network) );
                ok( 0, "find_network_labels should be called with expected configured values" );
            } );
        # THIS IS A UNIT TEST SO WE HAVE TO MOCK COLABORATORS -> recommendations
        my $mock_vm_placement = new Test::MockModule('LML::VMplacement');
        $mock_vm_placement->mock(
            'get_recommendations',
            sub {
                my ( $self, $vm_resources ) = @_;
                # verify that it was called with the expected arguments
                is_deeply(
                           $vm_resources,
                           {
                              "cpu"   => $expected_number_cpu,
                              "disks" => [ { "size" => $expected_diskSize } ],
                              "networks" => [ "network_label_1", "network_label_2" ],
                              "ram"      => $expected_memorySize,
                              "name"     => "devxxx02"
                           },
                           "get_recommendations should be called with expected vm_resources"
                );
                return ( ( { id => "id1", datastores => ['datastore1'], }, { id => "id2", datastores => ['datastore2'], } ) );

            } );

        my @vms = $vm_properties->generate_vms_array();
        is_deeply(
            \@vms,
            [ {
                  "custom_fields" => {
                                       "Contact User ID"   => "testuser",
                                       "Expires"           => "31.12.2019",
                                       "Force Boot"        => "ON",
                                       "Force Boot Target" => "default"
                  },
                  "datacenter"    => "some datacenter",
                  "datastore"     => "esx.id1:datastore1",    # must be the name resolved by Lab
                  "disksize"      => $expected_diskSize,
                  "force_network" => undef,
                  "guestid"       => "rhel6_64Guest",
                  "memory"        => $expected_memorySize,
                  "num_cpus"      => $expected_number_cpu,
                  "target_folder" => "some folder",
                  "vmhost"        => "id1.some.domain",       # must be the name resolved by Lab
                  "vmname"        => "devxxx02"
               }
            ],
            "should create vms_array with expected values"
        );
    }
}

done_testing();
