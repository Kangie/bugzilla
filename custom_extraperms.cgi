#!/usr/bin/perl -wT
use strict;

use lib qw(. lib);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;

my $cgi  = Bugzilla->cgi;
my $user = Bugzilla->login(LOGIN_REQUIRED);
my $dbh  = Bugzilla->switch_to_shadow_db();

my @bindValues;

print $cgi->header(-type => 'text/html');

     $user->in_group('admin')
  || $user->in_group('editusers')
  || $user->in_group('gentoo-dev')
  || ThrowUserError('auth_failure',
  {action => 'access', object => 'administrative_pages'});

my $sql_archtesters = "
SELECT 
profiles.login_name 
FROM 
	profiles 
	JOIN user_group_map ON user_id=profiles.userid 
	JOIN groups ON groups.id=group_id 
WHERE 
	user_id IN (SELECT user_id FROM user_group_map WHERE group_id=31) 
	AND group_id != 7 
	AND profiles.login_name NOT LIKE '%\@gentoo.org' 
GROUP BY login_name 
ORDER BY login_name;";
my $sql_otherperm = "
SELECT 
	profiles.login_name,
	groups.name AS group_name 
FROM 
	profiles 
	JOIN user_group_map ON user_id=profiles.userid 
	JOIN groups ON groups.id=group_id 
WHERE 
	user_id NOT IN (SELECT user_id FROM user_group_map WHERE group_id=31) 
	AND group_id != 7 
	AND profiles.login_name NOT LIKE '%\@gentoo.org' 
	AND groups.name != 'saved-searches'
GROUP BY login_name 
ORDER BY login_name;";

my $users;
$users = $dbh->selectall_arrayref($sql_archtesters, {Slice => {}}, @bindValues);

printf "<h3>Arch Testers that are not \@gentoo.org</h3>\n";
foreach my $row (@$users) {
  printf "<a href='%scustom_userhistory.cgi?matchstr=%s'>%s</a><br />\n",
    correct_urlbase(), $row->{'login_name'}, $row->{'login_name'};
}

$users = $dbh->selectall_arrayref($sql_otherperm, {Slice => {}}, @bindValues);
printf "<h3>Users with Other Groups</h3>\n";
foreach my $row (@$users) {
  printf "<a href='%scustom_userhistory.cgi?matchstr=%s'>%s</a>: %s<br />\n",
    correct_urlbase(), $row->{'login_name'}, $row->{'login_name'},
    $row->{'group_name'};
}
