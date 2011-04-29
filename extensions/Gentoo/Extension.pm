package Bugzilla::Extension::Gentoo;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla::Install::Filesystem qw(CGI_READ OWNER_EXECUTE WS_SERVE DIR_WS_SERVE);
use Bugzilla::Constants qw(bz_locations);

use POSIX;

our $VERSION = '1.0';

sub install_filesystem {
	my $datadir = bz_locations()->{'datadir'};

	my %files = (
		"zzz.txt"        => { perms => CGI_READ },
		"robots-ssl.txt" => { perms => CGI_READ },
		"bots.html"      => { perms => CGI_READ },
		"favicon.ico"    => { perms => CGI_READ },
		"runstats.sh"    => { perms => OWNER_EXECUTE },
		"recompile.sh"   => { perms => OWNER_EXECUTE },
    );

	my %recurse_dirs = (
		"$datadir/cached" => { files => WS_SERVE, dirs => DIR_WS_SERVE },
	);

	my %htaccess = (
		"$datadir/cached/.htaccess" => { perms => WS_SERVE, contents => <<EOT
# Allow access to the cached stuff
Allow from all
EOT
	);
}

sub template_before_create {
	my ($self, $args) = @_;

	my $config = $args->{config};
	my $constants = $config->{CONSTANTS};

	my %nodemap = (
		'hornbill' => 'bugs-web1',
		'hummingbird' => 'bugs-web2'
	);

	$constants->{GENTOO_NODE} = $nodemap{(POSIX::uname())[1]} ? $nodemap{(POSIX::uname())[1]} : "unknown";
	$constants->{GENTOO_APPEND_VERSION} = "-gentoo-r1";
}

__PACKAGE__->NAME;
