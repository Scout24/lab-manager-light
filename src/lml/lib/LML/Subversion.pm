package LML::Subversion;

use strict;
use Exporter;
use vars qw(
            $VERSION
            @ISA
            @EXPORT
           );
our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT   	= qw(svnCheckPath svnCopyPath svnMovePath);


sub svnCopyPath ($$) {
	my ($source,$destination) = @_;

	my $result = qx(svn copy -m "lml triggered" $source $destination 2>&1);
	if ($? > 0) {
		warn "'svn copy -m 'lml triggered' $source $destination' failed:\n$result";
		return undef;
	}
	#warn "copied $source -> $destination";
	return 1;
}

sub svnMovePath ($$) {
	my ($source,$destination) = @_;

	my $result = qx(svn move -m "lml triggered" $source $destination 2>&1);
	if ($? > 0) {
		warn "'svn move -m 'lml triggered' $source $destination' failed:\n$result";
		return undef;
	}
	#warn "moved $source $destination";
	return 1;
}					
use SVN::Client;

my $emptysub = sub {
	my( $path, $info, $pool ) = @_;
};

my $log_msg_callback = sub {
	my ($msg,$tmpfile,$items,$pool) = @_;
	$msg="lml";
};

#$ctx->log_msg($log_msg_callback);

sub svnCheckPath ($) {
	my $svnpath = shift;
	my $ctx = new SVN::Client();
	eval {
		$ctx->info($svnpath, undef, "HEAD", $emptysub , 0);
	};
	if ($@) {
		return undef;
	}
	return 1;
}

sub simple_prompt {
	my $cred = shift;
	my $realm = shift;
	my $default_username = shift;
	my $may_save = shift;
	my $pool = shift;

	print "Enter authentication info for realm: $realm\n";
	print "Username: ";
	my $username = <>;
	chomp($username);
	$cred->username($username);
	print "Password: ";
	my $password = <>;
	chomp($password);
	$cred->password($password);
}


1;
