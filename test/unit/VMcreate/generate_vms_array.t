use strict;
use warnings;

use Test::More;
use Test::Warn;
use Test::Exception;
use Test::MockModule;
use LML::Config;
#use Test::Mock::LWP::Dispatch;
use LWP::Simple qw(!head get);
use CGI qw(:standard);    # then only CGI.pm defines a head()

BEGIN {
    use_ok "LML::VMcreate::VMproperties";
}

my $C = new LML::Config(
                         {
                           vsphere => {
                                        expires_european => 1,
                                        datacenter       => "some datacenter"
                           },
                           hostrules => { pattern => '^[a-z]{6}[0-9]{2}$' },
                           vm_spec   => {
                                        host_announcement => 'some_host_announcement_url',
                                        host_spec         => 'some_host_spec_url'
                           }
                         }
);

#######################
# test cases
#######################

{
    my $vm_properties = new_ok(
                                "LML::VMcreate::VMproperties" => [
                                                                   $C,
                                                                   {
                                                                     name       => "devxxx02",
                                                                     expiration => "31.12.2019",
                                                                     username   => "testuser",
                                                                     esx_host   => "esx_server.some.domain",
                                                                     folder     => "some folder",
                                                                   }
                                ]
    );

    my $module = new Test::MockModule('LWP::Simple');
    $module->mock(
        'get',
        sub {
            return '{"virtualMachine" : {
                "name" : "foo", 
                "diskSize"  : 16384000,
                "memory" : 2048,
                "numberOfProcessors" : 1,
                "hasFrontend" : 0,
                "targetFolder" : "/dev-Systems/devage/"
                }
            }';

        }
    );

    my @vms = $vm_properties->generate_vms_array();

    is_deeply(
        \@vms,
        [
           {
              "custom_fields" => {
                                   "Contact User ID"   => "testuser",
                                   "Expires"           => "31.12.2019",
                                   "Force Boot"        => "ON",
                                   "Force Boot Target" => "default"
              },
              "datacenter"    => "some datacenter",
              "datastore"     => "esx_server:datastore1",
              "disksize"      => 16384000,
              "force_network" => undef,
              "guestid"       => "rhel6_64Guest",
              "has_frontend"  => 0,
              "memory"        => 2048,
              "num_cpus"      => 1,
              "target_folder" => "some folder",
              "vmhost"        => "esx_server.some.domain",
              "vmname"        => "devxxx02"
           }
        ],
        "should create vms_array with expected values"
    );

}
done_testing();
