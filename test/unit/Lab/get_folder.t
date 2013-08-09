use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Exception;

use Data::Dumper;

use LML::Lab;

my $LAB = new LML::Lab( {
                          FOLDERS => {
                                       "datacenter-21" => {
                                                            "name"   => "DC",
                                                            "parent" => "group-d1",
                                                            "path"   => "DC",
                                                            "type"   => "Datacenter"
                                       },
                                       "group-d1" => {
                                                       "name"   => "Datacenter",
                                                       "parent" => undef,
                                                       "path"   => "",
                                                       "type"   => "Folder"
                                       },
                                       "group-h23" => {
                                                        "name"   => "host",
                                                        "parent" => "datacenter-21",
                                                        "path"   => "DC/host",
                                                        "type"   => "Folder"
                                       },
                                       "group-n25" => {
                                                        "name"   => "network",
                                                        "parent" => "datacenter-21",
                                                        "path"   => "DC/network",
                                                        "type"   => "Folder"
                                       },
                                       "group-s24" => {
                                                        "name"   => "datastore",
                                                        "parent" => "datacenter-21",
                                                        "path"   => "DC/datastore",
                                                        "type"   => "Folder"
                                       },
                                       "group-v1003" => {
                                                          "name"   => "webserver",
                                                          "parent" => "group-v294",
                                                          "path"   => "DC/vm/test-systems/webserver",
                                                          "type"   => "Folder"
                                       },
                                       "group-v294" => {
                                                         "name"   => "tuvwgh",
                                                         "parent" => "group-v22",
                                                         "path"   => "DC/vm/test-systems",
                                                         "type"   => "Folder"
                                       },
                                       "group-v22" => {
                                                        "name"   => "vm",
                                                        "parent" => "datacenter-21",
                                                        "path"   => "DC/vm",
                                                        "type"   => "Folder"
                                       },
                          } } );

is( $LAB->get_folder("foobar"), undef, "should return undef if no folder found" );
dies_ok { $LAB->get_folder() } "should die if no folder to search given";
is_deeply(
           $LAB->get_folder("group-v294"),
           {
              "name"   => "tuvwgh",
              "parent" => "group-v22",
              "path"   => "DC/vm/test-systems",
              "type"   => "Folder"
           },
           "should return folder by id"
);
is_deeply(
           $LAB->get_folder("DC/vm/test-systems/webserver"),
           {
              "name"   => "webserver",
              "parent" => "group-v294",
              "path"   => "DC/vm/test-systems/webserver",
              "type"   => "Folder"
           },
           "should return folder by path"
);
done_testing();
