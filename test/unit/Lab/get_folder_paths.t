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

is_deeply(
    [ $LAB->get_folder_paths ],
    [ "", "DC", "DC/datastore", "DC/host", "DC/network", "DC/vm", "DC/vm/test-systems", "DC/vm/test-systems/webserver" ],
    "should return sorted list of folder paths"
);
is_deeply(
    [ $LAB->get_folder_paths("DC/vm/test-systems.*") ],
    [ "DC/vm/test-systems", "DC/vm/test-systems/webserver" ],
    "should return sorted list of folder paths limited to filter of full qualified start path"
);
is_deeply(
    [ $LAB->get_folder_paths(qr(.*vm.*)) ],
    [ "DC/vm", "DC/vm/test-systems", "DC/vm/test-systems/webserver" ],
    "should return sorted list of folder paths limited to given filter specifying all VM folders"
);
done_testing();
