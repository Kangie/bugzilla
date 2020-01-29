# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::BugUrl::Flyspray;
use strict;
use base qw(Bugzilla::BugUrl);

###############################
####        Methods        ####
###############################

sub should_handle {
  my ($class, $uri) = @_;

  # Flyspray URLs look like the following:
  #   https://bugs.flyspray.org/task/1237
  #   https://bugs.archlinux.org/task/44825
  return ($uri->path_query =~ m|/task/\d+$|) ? 1 : 0;
}

sub _check_value {
  my $class = shift;

  my $uri = $class->SUPER::_check_value(@_);

  # Remove any # part if there is one.
  $uri->fragment(undef);

  return $uri;
}

1;
