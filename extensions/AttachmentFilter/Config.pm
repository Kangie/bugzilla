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

use constant NAME => 'AttachmentFilter';

__PACKAGE__->NAME;
