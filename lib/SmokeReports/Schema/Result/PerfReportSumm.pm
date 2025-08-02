package SmokeReports::Schema::Result::PerfReportSumm;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table("pdc_perf_report_summ");
__PACKAGE__->add_columns
  (
   qw(report_id sha config_id summary_json needs_update),
  );
__PACKAGE__->set_primary_key("report_id");
__PACKAGE__->add_unique_constraint(sha_config => [ 'sha', 'config_id' ]);
__PACKAGE__->belongs_to('config', 'SmokeReports::Schema::Result::PerfConfig',
			{ 'foreign.id' => 'self.config_id' });

sub json_data($self) {
  require Cpanel::JSON::XS;

  state $json = Cpanel::JSON::XS->new;

  return $json->decode($self->summary_json);
}

1;
