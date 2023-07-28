package SmokeReports::Schema::Result::DailyBuildReport;
use v5.32.0;
use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('daily_build_reports');
__PACKAGE__->add_columns
  (
   id =>
   {
    is_auto_increment => 1,
    data_type => "integer",
   },
   qw/raw_report nntp_num msg_id/
  );
__PACKAGE__->set_primary_key("id");

__PACKAGE__->might_have
  (
   parsed_report => 'SmokeReports::Schema::Result::ParsedReport',
   { "foreign.nntp_id" => "self.nntp_num" },
   { join_type => "LEFT OUTER" }
  );

1;
