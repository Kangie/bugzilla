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
my ($query, $matchstr, $userid, $limit, $login_name);

print $cgi->header();

$matchstr = $cgi->param('matchstr');
$userid = $cgi->param('userid');
$userid = undef unless defined($userid) and $userid =~ /^\d+$/;
if(!defined($matchstr) and !defined($userid)) {
	print "No search parameters specified!<br/>\n";
	print "Put <tt>matchstr</tt> or <tt>userid</tt> in the URL parameters.<br/>\n";
	exit(0);
}
exit 0 if !defined($matchstr) and !defined($userid);

$limit = $cgi->param('limit');
$limit = 50 unless defined($limit) and $limit =~ /^\d+$/;

trick_taint($matchstr) if defined($matchstr);
trick_taint($userid) if defined($userid);
trick_taint($limit);

$userid = $matchstr ? login_to_id($matchstr) : $userid;
$login_name = $matchstr ? $matchstr : Bugzilla::User->new($userid)->login;

if(!$userid || !$login_name) {
	print "Bad user!<br/>";
	exit(0);
}

$query = qq{
(SELECT
		bug_id,
		bug_when,
		fielddefs.name AS field
	FROM
		bugs_activity
		JOIN fielddefs ON bugs_activity.fieldid=fielddefs.id
	WHERE
		who=?
	ORDER BY
		bug_when DESC
	LIMIT $limit)
UNION
(SELECT
		bug_id,
		bug_when,
		'ZZcomment #' AS field
	FROM
		longdescs
	WHERE
		who=?
	ORDER BY
		bug_when DESC
	LIMIT $limit)
UNION
(SELECT
		bug_id,
		creation_ts AS bug_when,
		CONCAT('ZZattachment #', attach_id)  AS field
	FROM
		attachments
	WHERE
		submitter_id=?
	ORDER BY
		creation_ts DESC
	LIMIT $limit)
ORDER BY bug_when DESC
LIMIT $limit};
my $actions = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
	($userid, $userid, $userid),
);

#print Dumper($vars);
printf "<h1>Custom User History: %s</h1>\n", $login_name;
print "<table>\n";
printf "<tr><th>login_name</th><td>%s</td></tr>\n",$login_name;
printf "<tr><th>userid</th><td>%s</td></tr>\n",$userid;
print "</table>\n";

sub show_bug_url {
	return "/show_bug.cgi?id=".shift;
}

print q{
<hr/>
<h2>Bug History</h2>
<table>
	<tr>
		<th>Timestamp</th>
		<th>BugID</th>
		<th>Field</th>
	</tr>
};
my $counter = 0;
foreach my $row (@$actions) {
	$counter++;
	my $url = show_bug_url($row->{'bug_id'});
	(my $message = qq{
		<tr>
			<td>$row->{'bug_when'}</td>
			<td><a href="${url}">$row->{'bug_id'}</a></td>
			<td>$row->{'field'}</td>
		</tr>
	}) =~ s/^\t{1}//mg;
	print $message;
}
printf "</table>.\nHistory Done.\nLimit=%d Count=%d<br/><br/>",$limit,$counter;

$query = q{
SELECT
	p2.userid AS grantor_id,
	p1.userid AS grantee_id,
	p2.login_name AS grantor,
	p1.login_name AS grantee,
	profiles_when,
	oldvalue,
	newvalue
FROM
	profiles p1
	JOIN profiles_activity ON p1.userid=profiles_activity.userid
	JOIN profiles p2 ON p2.userid=who
WHERE
	FALSE
	OR p1.userid = ?
	OR p2.userid = ?
ORDER BY
	profiles_when};
$actions = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
	($userid, $userid),
);

print "<hr/><h2>Profile Activity</h2>\n";
printf "<h3>Applied to %s:</h3>\n",$login_name;
print q{
<table>
	<tr>
		<th>Timestamp</th>
		<th>Grantor</th>
		<th>Grantee</th>
		<th>Oldvalue</th>
		<th>Newvalue</th>
	</tr>
};
foreach my $row (@$actions) {
    next unless $row->{'grantee_id'} == $userid;
	(my $message = qq{
		<tr>
			<td>$row->{'profiles_when'}</td>
			<td>$row->{'grantor'}</td>
			<td>$row->{'grantee'}</td>
			<td>$row->{'oldvalue'}</td>
			<td>$row->{'newvalue'}</td>
		</tr>
	}) =~ s/^\t{1}//mg;
	print $message;
}
print "</table>\n";

printf "<h3>Applied by %s:</h3>\n",$login_name;
print q{
<table>
	<tr>
		<th>Timestamp</th>
		<th>Grantor</th>
		<th>Grantee</th>
		<th>Oldvalue</th>
		<th>Newvalue</th>
	</tr>
};
foreach my $row (@$actions) {
    next unless $row->{'grantor_id'} == $userid;
	(my $message = qq{
		<tr>
			<td>$row->{'profiles_when'}</td>
			<td>$row->{'grantor'}</td>
			<td>$row->{'grantee'}</td>
			<td>$row->{'oldvalue'}</td>
			<td>$row->{'newvalue'}</td>
		</tr>
	}) =~ s/^\t{1}//mg;
	print $message;
}
print "</table>\n";

$query = q{
SELECT
	p1.userid AS watcher_id,
	p2.userid AS watched_id,
	p1.login_name AS watcher,
	p2.login_name AS watched
FROM
	profiles p1
	JOIN watch ON p1.userid=watch.watcher
	JOIN profiles p2 ON p2.userid=watch.watched
WHERE
	FALSE
	OR p1.userid = ?
	OR p2.userid = ?
ORDER BY
	watcher,watched
};
$actions = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
	($userid, $userid),
);
print "<hr/><h2>Watch status</h2>\n";
printf "<h3>Watchers of %s:</h3>\n", $login_name;
foreach my $row (@$actions) {
printf "%s<br/>\n", $row->{'watcher'} if $row->{'watched_id'} == $userid;
}
printf "<br/>\n";

printf "<h3>Watched by %s:</h3>", $login_name;
foreach my $row (@$actions) {
printf "%s<br/>\n", $row->{'watched'} if $row->{'watcher_id'} == $userid;
}
printf "<br/>\n";



$query = q{
SELECT
	user_id,
	class,
	object_id,
	field,
	at_time
FROM
	audit_log
WHERE
	FALSE
	OR user_id=?
	OR (class = 'Bugzilla::User' AND object_id=?)
ORDER BY
	at_time
};
my $audits = $dbh->selectall_arrayref(
    $query,
    { Slice => {} },
	($userid, $userid),
);

print "<hr/><h2>Audit log</h2>";
printf "<h3>Changes by %s:</h3>\n", $login_name;
print q{
<table>
	<tr>
		<th>Timestamp</th>
		<th>UserID</th>
		<th>Class/ID</th>
		<th>Field</th>
	</tr>
};
foreach my $row (@$audits) {
	next unless $row->{'user_id'} == $userid;
	(my $message = qq{
		<tr>
			<td>$row->{'at_time'}</td>
			<td>$row->{'user_id'}</td>
			<td>$row->{'class'}/$row->{'object_id'}</td>
			<td>$row->{'field'}</td>
		</tr>
	}) =~ s/^\t{1}//mg;
	print $message;
}
print "</table>\n";

printf "<h3>Changes to %s:</h3>", $login_name;
print "<table>\n";
print "<tr><th>Timestamp</th><th>UserID</th><th>Class/ID</th><th>Field</th></tr>\n";
foreach my $row (@$audits) {
	next unless $row->{'object_id'} == $userid && $row->{'class'} eq 'Bugzilla::User';
	(my $message = qq{
		<tr>
			<td>$row->{'at_time'}</td>
			<td>$row->{'user_id'}</td>
			<td>$row->{'class'}/$row->{'object_id'}</td>
			<td>$row->{'field'}</td>
		</tr>
	}) =~ s/^\t{2}//mg;
	print $message;
}
print "</table>\n";
printf "<hr/>Done.<br/>\n";
