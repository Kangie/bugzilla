# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

#######################
###Bugzilla Test 14####
#BugUrl Local/External#

# These are unit tests for the Local and External BugUrl classes.
# They test URL classification, validation, and normalisation.
# There's lots of mocking, but we're only testing the BugUrl classes themselves.

use 5.14.0;
use strict;
use warnings;

use lib qw(. lib t);
use Test::More tests => 41;
use URI;

#####################################################################
# Mock Environment Setup
#####################################################################

BEGIN {
  # Set up minimal package stubs to avoid "use" errors
  $INC{'Bugzilla/LocalConfig.pm'} = 1;
  $INC{'Bugzilla.pm'} = 1;
  $INC{'Bugzilla/Bug.pm'} = 1;
  $INC{'Bugzilla/Error.pm'} = 1;
  $INC{'Bugzilla/Util.pm'} = 1;
  $INC{'Bugzilla/Constants.pm'} = 1;
  $INC{'Bugzilla/Object.pm'} = 1;
  $INC{'Bugzilla/Hook.pm'} = 1;

  package Bugzilla::LocalConfig {
    sub new { bless {}, shift }
    sub urlbase { 'https://bugs.example.com/' }
  }

  package Bugzilla {
    sub localconfig { Bugzilla::LocalConfig->new() }
    sub params { {'urlbase' => 'https://bugs.example.com/'} }
  }

  package Bugzilla::Bug {
    require Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(bug_alias_to_id);

    our %mock_bugs = (123 => {id => 123}, 456 => {id => 456}, 789 => {id => 789});
    sub check {
      my ($class, $param) = @_;
      my $id = ref($param) eq 'HASH' ? $param->{id} : $param;
      die "USER ERROR: bug_id_does_not_exist\n" unless exists $mock_bugs{$id};
      return bless $mock_bugs{$id}, $class;
    }
    sub check_is_visible { 1 }
    sub id { $_[0]->{id} }
    sub bug_alias_to_id {
      return 456 if $_[0] eq 'valid_alias';
      return undef;
    }
  }

  package Bugzilla::Error {
    require Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT = qw(ThrowCodeError ThrowUserError);
    sub ThrowCodeError { die "CODE ERROR: $_[0]\n" }
    sub ThrowUserError { die "USER ERROR: $_[0]\n" }
  }

  package Bugzilla::Util {
    require Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT = qw(detaint_natural);
    sub detaint_natural { return 1 if $_[0] && $_[0] =~ /^\d+$/; return 0 }
  }

  package Bugzilla::Constants {
    require Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT = qw(MAX_BUG_URL_LENGTH);
    use constant MAX_BUG_URL_LENGTH => 255;
  }

  package Bugzilla::Object { sub new { bless {}, shift } }
  package Bugzilla::Hook { sub process { } }
}

# Load the modules we're testing
BEGIN {
  use_ok('Bugzilla::BugUrl');
  use_ok('Bugzilla::BugUrl::Local');
  use_ok('Bugzilla::BugUrl::External');
}

#####################################################################
# Test Bugzilla::BugUrl base class
#####################################################################

# Test local_uri() method
{
  my $uri = Bugzilla::BugUrl->local_uri();
  is($uri, 'https://bugs.example.com/show_bug.cgi?id=', 'local_uri with no bug_id');

  $uri = Bugzilla::BugUrl->local_uri(123);
  is($uri, 'https://bugs.example.com/show_bug.cgi?id=123', 'local_uri with bug_id');
}

#####################################################################
# Test Bugzilla::BugUrl::External
#####################################################################

# should_handle() - accepts external URLs
{
  ok(Bugzilla::BugUrl::External->should_handle(URI->new('https://github.com/user/repo/issues/1')),
    'External handles GitHub HTTPS URL');

  ok(Bugzilla::BugUrl::External->should_handle(URI->new('http://external.org/bug/123')),
    'External handles HTTP external URL');
}

# should_handle() - rejects non-http[s] URLs
{
  ok(!Bugzilla::BugUrl::External->should_handle(URI->new('ftp://files.com/bug')),
    'External rejects FTP URL');
}

# _check_value() - validates and normalises
{
  my $uri = URI->new('https://external.com/bug/123');
  my $result = Bugzilla::BugUrl::External->_check_value($uri);
  is($result->as_string, 'https://external.com/bug/123', 'HTTPS URL passes through');

  $uri = URI->new('http://external.com/bug/456');
  $result = Bugzilla::BugUrl::External->_check_value($uri);
  is($result->scheme, 'https', 'HTTP converted to HTTPS');
}

# _check_value() - error cases
{
  eval { Bugzilla::BugUrl::External->_check_value(URI->new('ftp://external.com/file')) };
  like($@, qr/USER ERROR: bug_url_invalid/, 'FTP scheme throws error');

  eval { Bugzilla::BugUrl::External->_check_value(URI->new('https:///path/to/bug')) };
  like($@, qr/USER ERROR: bug_url_invalid/, 'Missing authority throws error');

  my $long_path = '/bug/' . ('x' x 300);
  eval { Bugzilla::BugUrl::External->_check_value(URI->new("https://external.com$long_path")) };
  like($@, qr/USER ERROR: bug_url_too_long/, 'Overly long URL throws error');
}

#####################################################################
# Test Bugzilla::BugUrl::Local
#####################################################################

# should_handle() - accepts local formats
{
  ok(Bugzilla::BugUrl::Local->should_handle(URI->new('123')),
    'Local handles plain numeric bug ID');

  ok(Bugzilla::BugUrl::Local->should_handle(URI->new('valid_alias')),
    'Local handles bug alias');

  ok(Bugzilla::BugUrl::Local->should_handle(URI->new('https://bugs.example.com/show_bug.cgi?id=123')),
    'Local handles local full URL');

  ok(Bugzilla::BugUrl::Local->should_handle(URI->new('https://bugs.example.com/123')),
    'Local handles shorthand /123 format');
}

# should_handle() - rejects external URLs
{
  ok(!Bugzilla::BugUrl::Local->should_handle(URI->new('https://external.com/bug/123')),
    'Local rejects external domain');

  ok(!Bugzilla::BugUrl::Local->should_handle(URI->new('https://bugs.example.com/some/other/path')),
    'Local rejects non-bug path');
}

# _check_value() - plain bug ID
{
  my $uri = URI->new('123');
  my $params = {bug_id => 456};

  my $result = Bugzilla::BugUrl::Local->_check_value($uri, undef, $params);

  ok($result, 'Returns a URI object');
  is($result->query_param('id'), '123', 'Bug ID is set correctly');
  like($result->as_string, qr/show_bug\.cgi/, 'Contains show_bug.cgi');
  like($result->as_string, qr/bugs\.example\.com/, 'Contains local domain');
}

# _check_value() - bug alias resolution
{
  my $uri = URI->new('valid_alias');
  my $params = {bug_id => 123};

  my $result = Bugzilla::BugUrl::Local->_check_value($uri, undef, $params);

  is($result->query_param('id'), '456', 'Alias resolved to correct bug ID');
  like($result->as_string, qr/show_bug\.cgi\?id=456/, 'Final URL contains resolved ID');
}

# _check_value() - invalid alias
{
  eval {
    my $uri = URI->new('invalid_alias');
    Bugzilla::BugUrl::Local->_check_value($uri, undef, {bug_id => 123});
  };
  like($@, qr/USER ERROR: improper_bug_id_field_value/, 'Invalid alias throws error');
}

# _check_value() - URL normalisation
{
  my $params = {bug_id => 456};

  # Full local URL
  my $uri = URI->new('https://bugs.example.com/show_bug.cgi?id=123');
  my $result = Bugzilla::BugUrl::Local->_check_value($uri, undef, $params);
  is($result->query_param('id'), '123', 'Bug ID extracted from full URL');

  # URL with extra query parameters - should be stripped
  $uri = URI->new('https://bugs.example.com/show_bug.cgi?id=123&foo=bar');
  $result = Bugzilla::BugUrl::Local->_check_value($uri, undef, $params);
  is($result->query, 'id=123', 'Extra parameters stripped');

  # URL with fragment - should be removed
  $uri = URI->new('https://bugs.example.com/show_bug.cgi?id=123#comment-5');
  $result = Bugzilla::BugUrl::Local->_check_value($uri, undef, $params);
  is($result->fragment, undef, 'Fragment removed');

  # Shorthand /123 format
  $uri = URI->new('https://bugs.example.com/123');
  $result = Bugzilla::BugUrl::Local->_check_value($uri, undef, $params);
  is($result->query_param('id'), '123', 'Bug ID extracted from /123 format');
  like($result->path, qr/show_bug\.cgi/, 'Path normalised to show_bug.cgi');
}

# _check_value() - self-reference detection
{
  eval {
    my $uri = URI->new('123');
    Bugzilla::BugUrl::Local->_check_value($uri, undef, {bug_id => 123});
  };
  like($@, qr/USER ERROR: see_also_self_reference/, 'Self-reference throws error');
}

# _check_value() - non-existent bug
{
  eval {
    my $uri = URI->new('999999');
    Bugzilla::BugUrl::Local->_check_value($uri, undef, {bug_id => 123});
  };
  like($@, qr/USER ERROR: bug_id_does_not_exist/, 'Non-existent bug throws error');
}

# _check_value() - invalid bug ID in URL
{
  eval {
    my $uri = URI->new('https://bugs.example.com/show_bug.cgi');
    Bugzilla::BugUrl::Local->_check_value($uri, undef, {bug_id => 123});
  };
  like($@, qr/USER ERROR: bug_url_invalid/, 'URL without id parameter throws error');
}

# target_bug_id()
{
  my $bugurl = bless {
    name => 'https://bugs.example.com/show_bug.cgi?id=789',
  }, 'Bugzilla::BugUrl::Local';

  # Add accessor since we're not using full Object infrastructure
  no warnings 'redefine';
  local *Bugzilla::BugUrl::Local::name = sub { $_[0]->{name} };

  is($bugurl->target_bug_id(), '789', 'Extracts correct bug ID from stored URL');
}

#####################################################################
# Integration - class selection
#####################################################################

# class_for() - External URLs
{
  my $class = Bugzilla::BugUrl->class_for('https://github.com/user/repo/issues/1');
  is($class, 'Bugzilla::BugUrl::External', 'GitHub URL → External class');

  $class = Bugzilla::BugUrl->class_for('http://external.org/bug/1');
  is($class, 'Bugzilla::BugUrl::External', 'External HTTP URL → External class');
}

# class_for() - Local URLs
{
  my $class = Bugzilla::BugUrl->class_for('https://bugs.example.com/show_bug.cgi?id=1');
  is($class, 'Bugzilla::BugUrl::Local', 'Local full URL → Local class');

  $class = Bugzilla::BugUrl->class_for('123');
  is($class, 'Bugzilla::BugUrl::Local', 'Plain ID → Local class');

  $class = Bugzilla::BugUrl->class_for('valid_alias');
  is($class, 'Bugzilla::BugUrl::Local', 'Alias → Local class');
}

# class_for() - Invalid URLs
{
  eval { Bugzilla::BugUrl->class_for('ftp://files.example.com/bug') };
  like($@, qr/USER ERROR: bug_url_invalid/, 'FTP URL rejected by both classes');
}
