#!/usr/bin/perl -wT
use strict;

use lib qw(. lib);

use Data::Dumper;
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;
use Bugzilla::User;

my $cgi       = Bugzilla->cgi;
my $vars      = {};
my $myuser = Bugzilla->login(LOGIN_REQUIRED);
my $dbh       = Bugzilla->switch_to_shadow_db();
my @bindValues;
my $query;

print $cgi->header();

my $matchstr = $cgi->param('matchstr');
my $userid = $cgi->param('userid');
if(!defined($matchstr) and !defined($userid)) {
	print "No search parameters specified!<br/>";
	exit(0);
}
exit 0 if !defined($matchstr) and !defined($userid);

my $limit = $cgi->param('limit');
$limit = 50 unless defined($limit) and $limit =~ /^\d+$/;

trick_taint($matchstr) if defined($matchstr);
trick_taint($userid) if defined($userid);
trick_taint($limit);

$userid = $matchstr ? login_to_id($matchstr) : $userid;
my $login_name = $matchstr ? $matchstr : Bugzilla::User->new($matchstr)->login;

if(!$userid || !$login_name) {
	print "Bad user!<br>";
	exit(0);
}

my @bindValues2;
$query = sprintf
	'(SELECT bug_id, bug_when, fielddefs.name AS field '.
		'FROM bugs_activity JOIN fielddefs ON bugs_activity.fieldid=fielddefs.id '.
		'WHERE who=? '.
		'ORDER BY bug_when DESC '.
		'LIMIT %d) '.
	'UNION '.
	'(SELECT bug_id, bug_when, \'ZZcomment #\' AS field '.
		'FROM longdescs '.
		'WHERE who=? '.
		'ORDER BY bug_when DESC '.
		'LIMIT %d) '.
	'UNION '.
	'(SELECT bug_id, creation_ts AS bug_when, CONCAT(\'ZZattachment #\', attach_id)  AS field '.
		'FROM attachments '.
		'WHERE submitter_id=? '.
		'ORDER BY creation_ts DESC '.
		'LIMIT %d) '.
	'ORDER BY bug_when DESC '.
	'LIMIT %d',
	$limit,$limit,$limit,$limit;

push(@bindValues2, $userid);
push(@bindValues2, $userid);
push(@bindValues2, $userid);

#print Dumper($vars);
printf "%s<br>",$login_name;
my $actions = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
	@bindValues2
);

my $counter = 0;
foreach my $row (@$actions) {
	printf "<a href=\"%9d\">%9d</a>: %s %s<br>", $row->{'bug_id'}, $row->{'bug_id'}, $row->{'bug_when'}, $row->{'field'};
	$counter++;
}
printf "History Done. Limit=%d Count=%d<br><br>",$limit,$counter;

$query = 'SELECT
p2.userid AS grantor_id, p1.userid AS grantee_id,
p2.login_name AS grantor, p1.login_name AS grantee,profiles_when,oldvalue,newvalue
FROM profiles p1
JOIN profiles_activity ON p1.userid=profiles_activity.userid
JOIN profiles p2 ON p2.userid=who
WHERE p1.userid = ? OR p2.userid = ?
ORDER BY profiles_when';
my @bindValues3;
push(@bindValues3, $userid);
push(@bindValues3, $userid);
$actions = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
	@bindValues3
);

printf "Applied to %s:<br>",$login_name;
foreach my $row (@$actions) {
	printf "%s: by %s: %s%s %s%s<br>", $row->{'profiles_when'}, $row->{'grantor'}, $row->{'oldvalue'} ? '-' : '', $row->{'oldvalue'}, $row->{'newvalue'}? '+' : '', $row->{'newvalue'} if $row->{'grantee_id'} == $userid;
}
printf "<br>";

printf "Applied by %s:<br>",$login_name;
foreach my $row (@$actions) {
	printf "%s: to %s: %s%s %s%s<br>", $row->{'profiles_when'}, $row->{'grantee'}, $row->{'oldvalue'} ? '-' : '', $row->{'oldvalue'}, $row->{'newvalue'}? '+' : '', $row->{'newvalue'} if $row->{'grantor_id'} == $userid;
}
printf "<br>";

$query = 'SELECT
p1.userid AS watcher_id, p2.userid AS watched_id,
p1.login_name AS watcher, p2.login_name AS watched
FROM profiles p1
JOIN watch ON p1.userid=watch.watcher
JOIN profiles p2 ON p2.userid=watch.watched
ORDER BY watcher,watched
';
$actions = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
);
printf "Watchers of %s:<br>", $login_name;
foreach my $row (@$actions) {
printf "%s<br>", $row->{'watcher'} if $row->{'watched_id'} == $userid;
}
printf "<br>";

printf "Watched by %s:<br>", $login_name;
foreach my $row (@$actions) {
printf "%s<br>", $row->{'watched'} if $row->{'watcher_id'} == $userid;
}
printf "<br>";

printf "Done.<br>";
