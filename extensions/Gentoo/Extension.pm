package Bugzilla::Extension::Gentoo;
use strict;
use base qw(Bugzilla::Extension);

#use Bugzilla::Install::Filesystem qw(CGI_READ OWNER_EXECUTE WS_SERVE DIR_WS_SERVE);
use Bugzilla::Constants qw(bz_locations);
use Bugzilla::Error qw(ThrowUserError);

use POSIX qw(uname);

our $VERSION = '1.0';

sub install_filesystem {
  my ($self, $args) = @_;

  my $dirs         = $args->{'create_dirs'};
  my $files        = $args->{'files'};
  my $recurse_dirs = $args->{'recurse_dirs'};
  my $htaccess     = $args->{'htaccess'};

  my $datadir = bz_locations()->{'datadir'};

  $dirs->{"${datadir}/cached"} = {perms => 0750};

  $files->{"zzz.txt"}        = {perms => 0644};
  $files->{"robots-ssl.txt"} = {perms => 0644};
  $files->{"bots.html"}      = {perms => 0644};
  $files->{"favicon.ico"}    = {perms => 0644};
  $files->{"runstats.sh"}    = {perms => 0700};
  $files->{"recompile.sh"}   = {perms => 0700};

  $recurse_dirs->{"$datadir/cached"} = {files => 0640, dirs => 0750};

  $recurse_dirs->{"images/ranks"} = {files => 0640, dirs => 0750};

  $htaccess->{"$datadir/cached/.htaccess"} = {
    perms    => 0640,
    contents => <<EOT
# Allow access to the cached stuff
Allow from all
EOT
  };
}

sub template_before_create {
  my ($self, $args) = @_;

  my $config    = $args->{config};
  my $constants = $config->{CONSTANTS};

  my %nodemap = ('yellowbishop' => 'bugs-web1', 'yellowleg' => 'bugs-web2');

  my $hostname = (uname())[1];
  $constants->{GENTOO_NODE}
    = $nodemap{$hostname} ? $nodemap{$hostname} : "[$hostname]";
  $constants->{GENTOO_APPEND_VERSION} = "+";
}

sub user_check_account_creation {
  my ($self, $args) = @_;

  my $login = $args->{login};

  ThrowUserError('restricted_email_address', {addr => $login})
    if $login =~ m/.+\@gentoo\.org$/;
}

__PACKAGE__->NAME;
