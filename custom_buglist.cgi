#!/usr/bin/perl -wT
# This copy of buglist is simple and stupid, just for bots
use strict;

use lib qw(. lib);

use Data::Dumper;
use DateTime;
use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Util;

my $cgi      = Bugzilla->cgi;
my $template = Bugzilla->template;
my $vars     = {};
my $dbh      = Bugzilla->switch_to_shadow_db();
my @bindValues;

print $cgi->header(-type => 'text/html');
my $reso   = $cgi->param('reso');
my $status = $cgi->param('status');
my $since  = $cgi->param('since');
$status = undef unless defined($status);
$reso   = undef unless defined($reso);
$since  = undef unless defined($since) and $since =~ /^[0-9]+/;

trick_taint($reso)   if defined($reso);
trick_taint($status) if defined($status);
trick_taint($since)  if defined($since);

# SELECT profiles.login_name,bugs.bug_id,short_desc,priority,resolution,rep_platform,bug_status,bug_severity,profilesb.login_name AS reporter FROM bugs LEFT JOIN profiles ON bugs.assigned_to = profiles.userid LEFT JOIN profiles AS profilesb ON bugs.reporter = profilesb.userid LEFT JOIN bug_group_map ON bug_group_map.bug_id = bugs.bug_id WHERE bugs.bug_id=160786 AND (bug_group_map.group_id IS NULL OR bug_group_map.group_id!=24)

my @bindValues2;
my ($reso_sql,  $status_sql,  $since_sql);
my ($reso_desc, $status_desc, $since_desc);
$reso_sql  = $status_sql  = $since_sql  = '1';
$reso_desc = $status_desc = $since_desc = '';
if (defined($reso)) {
  $reso_sql = 'resolution=?';
  push(@bindValues2, $reso);
  $reso_desc = 'with resolution ' . $reso;
}
if (defined($status)) {
  $status_sql = 'bug_status=?';
  push(@bindValues2, $status);
  $status_desc = 'with status ' . $status;
}
if (defined($since)) {
  $since_sql = 'since=?';
  push(@bindValues2, $since);
  $since_desc = 'since ' . $since;
}
my $query2 = sprintf 'SELECT
                        bugs.bug_id, short_desc, priority,
                        resolution, bug_status, bug_severity
                        FROM bugs
                        LEFT JOIN bug_group_map ON bug_group_map.bug_id = bugs.bug_id
                        WHERE bug_group_map.group_id IS NULL
                                AND %s
                                AND %s
                                AND %s', $reso_sql, $status_sql, $since_sql;


#print Dumper($vars);
my $title = sprintf "Bug listing %s %s %s as at %s", $status_desc, $reso_desc,
  $since_desc, DateTime->now->strftime("%Y/%m/%d %H:%M:%S");
print
  '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">'
  . "\n";
printf "<head><title>$title</title></head>\n";
printf "<body><h1>%s</h1>\n", $title;
my $actions = $dbh->selectall_arrayref($query2, {Slice => {}}, @bindValues2);

my $counter = 0;
print "<div><ul>";
foreach my $row (@$actions) {
  printf
    "<li><a href='%s%d'>Bug:%d - \"<em>%s</em>\" status:%s resolution:%s severity:%s</a></li>\n",
    correct_urlbase(), $row->{'bug_id'}, $row->{'bug_id'},
    html_quote($row->{'short_desc'}), $row->{'bug_status'}, $row->{'resolution'},
    $row->{'bug_severity'};
  $counter++;
}
printf "</ul>Done. Count=%d</div></body></html>\n", $counter;
