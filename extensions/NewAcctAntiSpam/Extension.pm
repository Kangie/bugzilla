package Bugzilla::Extension::NewAcctAntiSpam;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use DateTime;

use Bugzilla::Error;
use Bugzilla::Util qw(remote_ip datetime_from);

BEGIN {
  *Bugzilla::User::acct_created_ts     = \&_user_acct_created_ts;
  *Bugzilla::User::set_acct_created_ts = \&_user_set_acct_created_ts;
}

sub _user_acct_created_ts { $_[0]->{acct_created_ts} }

sub _user_set_acct_created_ts {
  my ($self, $value) = @_;
  $self->set('acct_created_ts', $_[1]);

  Bugzilla->dbh->do("UPDATE profiles SET acct_created_ts = ? WHERE userid = ?",
    undef, $value, $self->id);
  Bugzilla->memcached->clear({table => 'profiles', id => $self->id});
}

sub object_end_of_create {
  my ($self, $args) = @_;
  my $object = $args->{object} or return;
  return if exists $args->{changes} && !scalar(keys %{$args->{changes}});

  if ($object->isa('Bugzilla::User')) {
    my $now = DateTime->now->datetime(' ');
    $object->set_acct_created_ts($now);
  }
}

sub object_end_of_create_validators {
  my ($self, $args) = @_;
  if ($args->{class} eq 'Bugzilla::Comment') {
    if ($args->{params}->{thetext} =~ /https?:\/\//i) {
      my $user      = Bugzilla->user;
      my $created   = $user->acct_created_ts;
      if ($created) {
        my $dayafter = (datetime_from($created)
          + DateTime::Duration->new(days => 1));
        if (DateTime->now < $dayafter) {
          ThrowUserError('antispam_comment_blocked');
        }
      }
    }
  }
}

sub object_columns {
  my ($self,  $args)    = @_;
  my ($class, $columns) = @$args{qw(class columns)};
  if ($class->isa('Bugzilla::User')) {
    push(@$columns, qw(acct_created_ts));
  }
}

sub object_update_columns {
  my ($self,   $args)    = @_;
  my ($object, $columns) = @$args{qw(object columns)};
  if ($object->isa('Bugzilla::User')) {
    push(@$columns, qw(acct_created_ts));
  }
}

sub install_update_db {
  my $dbh = Bugzilla->dbh;
  $dbh->bz_add_column('profiles', 'acct_created_ts', {TYPE => 'DATETIME'});
}

__PACKAGE__->NAME;
