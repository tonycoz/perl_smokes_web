package SmokeReports::Schema::Result::PerfReport;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table("pdc_perf_reports");
__PACKAGE__->add_columns
  (
   id =>
   {
    is_auto_increment => 1,
    data_type => "integer",
   },
   qw(sha config_id report_json mod_at report_sha report_gzip),
  );
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(sha_config => [ 'sha', 'config_id' ]);
__PACKAGE__->belongs_to('config', 'SmokeReports::Schema::Result::PerfConfig',
			{ 'foreign.id' => 'self.config_id' });
__PACKAGE__->might_have
  (
   summary => 'SmokeReports::Schema::Result::PerfReportSumm',
   { 'foreign.report_id' => 'self.id' },
   { join_type => "LEFT OUTER" },
  );

sub json_data($self) {
  require Cpanel::JSON::XS;

  state $json = Cpanel::JSON::XS->new;

  return $json->decode($self->report_json);
}

1;
