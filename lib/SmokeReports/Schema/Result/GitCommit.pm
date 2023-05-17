package SmokeReports::Schema::Result::GitCommit;
use v5.32.0;
use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('git_commits');
__PACKAGE__->add_columns(qw/id branch ordering parent_id sha subject seen_at/);
__PACKAGE__->set_primary_key("id");

1;
