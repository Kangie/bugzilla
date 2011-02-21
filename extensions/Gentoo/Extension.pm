package Bugzilla::Extension::Gentoo;
use strict;
use base qw(Bugzilla::Extension);

use POSIX;

our $VERSION = '1.0';

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
