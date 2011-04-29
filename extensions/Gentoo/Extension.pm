package Bugzilla::Extension::Gentoo;
use strict;
use base qw(Bugzilla::Extension);

#use Bugzilla::Install::Filesystem qw(CGI_READ OWNER_EXECUTE WS_SERVE DIR_WS_SERVE);
use Bugzilla::Constants qw(bz_locations);

use POSIX qw(uname);

our $VERSION = '1.0';

sub install_filesystem {
	my $datadir = bz_locations()->{'datadir'};

	my %files = (
		"zzz.txt"        => { perms => 0644 },
		"robots-ssl.txt" => { perms => 0644 },
		"bots.html"      => { perms => 0644 },
		"favicon.ico"    => { perms => 0644 },
		"runstats.sh"    => { perms => 0700 },
		"recompile.sh"   => { perms => 0700 },
    );

	my %recurse_dirs = (
		"$datadir/cached" => { files => 0640, dirs => 0750 },
	);

	my %htaccess = (
		"$datadir/cached/.htaccess" => { perms => 0640, contents => <<EOT
# Allow access to the cached stuff
Allow from all
EOT
		},
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

	$constants->{GENTOO_NODE} = $nodemap{(uname())[1]} ? $nodemap{(uname())[1]} : "unknown";
	$constants->{GENTOO_APPEND_VERSION} = "-gentoo-r1";
}

__PACKAGE__->NAME;
