# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This extension is filtering attachments.
#
# Currently its is filtering html attachments.
#
# Contributor(s):
#   Max Magorsch <arzano@gentoo.org>

package Bugzilla::Extension::AttachmentFilter;
use strict;
use base qw(Bugzilla::Extension);
use Bugzilla::Error;

our $VERSION = '0.02';
################################################################################
# This extension is filtering attachments. Currently its is filtering html
# attachments.
################################################################################
sub attachment_process_data {
  my ($self, $args) = @_;
  return unless ($args->{attributes}->{mimetype} eq 'text/html') or
                ($args->{attributes}->{filename} =~ /\.htm\z/) or
                ($args->{attributes}->{filename} =~ /\.html\z/) or
                ($args->{attributes}->{filename} =~ /\.php\z/);

  ${$args->{data}} = '';
  $args->{attributes}->{filename} = '';

  ThrowUserError("illegal_html_attachment");
}

__PACKAGE__->NAME;
