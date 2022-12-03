# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::Gentoo::GentooBugzilla;

use 5.10.1;
use strict;
use warnings;

use parent qw(Bugzilla::BugUrl::Bugzilla::Local);

use URI ();

###############################
####        Methods        ####
###############################

sub should_handle {
  my ($class, $uri) = @_;

  # Gentoo Bugzilla issues have the form of
  # bugs.gentoo.org/123456
  return (lc($uri->authority) eq "bugs.gentoo.org"
      && $uri->path =~ m|^/\d+$|) ? 1 : 0;
}

sub _check_value {
  my ($class, $uri, undef, $params) = @_;

  my $local_uri = URI->new(substr($uri->path, 1));

  return $class->SUPER::_check_value($local_uri, undef, $params);
}

1;

