package TestTools::VmCreateOptions;

use strict;
use warnings;

use Getopt::Long;

sub new {
    my ($class) = @_;

    my $boot_timeout = 45;
    my $test_host;
    my $vm_name_prefix;
    my $esx_host;
    my $username;
    my $expiration_date = DateTime->today()->add( days => 1 )->dmy(".");
    my $folder;
    my $force_boot_target = 'qrdata';
    my $lmlhostpattern;

    my $vm_number;
    my @time = localtime(time);
    my $time = $time[1] + 1;
    if ( $time < 10 ) {
        $vm_number = "0" . $time;
    } else {
        $vm_number = $time;
    }

    if (
         !GetOptions(
                      "boot_timeout=i"    => \$boot_timeout,
                      "test_host=s"       => \$test_host,
                      "vm_name_prefix=s"  => \$vm_name_prefix,
                      "esx_host=s"        => \$esx_host,
                      "username=s"        => \$username,
                      "expiration_date=s" => \$expiration_date,
                      "folder=s"          => \$folder,
                      "lmlhostpattern=s"  => \$lmlhostpattern,
         )
      )
    {
        print "##teamcity[buildStatus status='FAILURE' text='Missing options']\n";
        exit 1;
    }

    # make sure that everything is set
    if ( not( $test_host and $vm_name_prefix and $esx_host and $username and $folder and $lmlhostpattern ) ) {
        print "##teamcity[buildStatus status='FAILURE' text='Need to provide at least test_host, vm_name_prefix, esx_host, username, folder and lmlhostpattern options.']\n";
        exit 1;
    }

    my $self = {
                 boot_timeout      => $boot_timeout,
                 test_host         => $test_host,
                 vm_name_prefix    => $vm_name_prefix,
                 esx_host          => $esx_host,
                 username          => $username,
                 expiration_date   => $expiration_date,
                 folder            => $folder,
                 lmlhostpattern    => $lmlhostpattern,
                 vm_host           => $vm_name_prefix . $vm_number,
                 force_boot_target => $force_boot_target,
    };

    bless( $self, $class );

    return $self;
}

1;
