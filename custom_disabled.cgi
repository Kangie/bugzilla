#!/usr/bin/perl -wT
use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;

my $cgi  = Bugzilla->cgi;
my $vars = {};
my $user = Bugzilla->login(LOGIN_REQUIRED);
my $dbh  = Bugzilla->switch_to_shadow_db();

print $cgi->header(-type => 'text/html');

     $user->in_group('admin')
  || $user->in_group('editusers')
  || $user->in_group('gentoo-dev')
  || ThrowUserError('auth_failure',
  {action => 'access', object => 'administrative_pages'});

my $query
  = 'SELECT DISTINCT userid, login_name, realname, disabledtext, disable_mail '
  . 'FROM profiles '
  . 'WHERE LENGTH(profiles.disabledtext) > 0';
$vars->{'users'} = $dbh->selectall_arrayref($query, {Slice => {}});

#use Data::Dumper;
#print Dumper($vars);

foreach my $user (@{$vars->{'users'}}) {
  next
    if ($user->{'realname'} =~ m/\(RETIRED\)$/
    and $user->{'disabledtext'} =~ m/retired/i);

  $user->{'disabledtext'} =~ s/\n/<br>/g;

  # Add bug links
  $user->{'disabledtext'} =~ s/(bug (\d+(#c\d+)?))/<a href="\/$2">$1<\/a>/g;

  printf("Login=<a href=\"/editusers.cgi?action=edit&userid=%i\">%s</a><br>",
    $user->{'userid'}, $user->{'login_name'});
  printf("Real Name=%s<br>",         $user->{'realname'});
  printf("Bugmail Disabled: %s<br>", $user->{'disable_mail'} eq 1 ? "Yes" : "No");
  printf("Disabled Text=%s<br><br>", $user->{'disabledtext'});
}
