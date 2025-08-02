package SmokeReports::Schema::Result::User;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table("pdc_users");
__PACKAGE__->add_columns
  (
   id =>
   {
    is_auto_increment => 1,
    data_type => "integer",
   },
   qw(login),
  );
__PACKAGE__->set_primary_key("id");

1;
