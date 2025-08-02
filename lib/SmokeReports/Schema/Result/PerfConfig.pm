package SmokeReports::Schema::Result::PerfConfig;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table("pdc_perf_config");
__PACKAGE__->add_columns
  (
   id =>
   {
    is_auto_increment => 1,
    data_type => "integer",
   },
   qw(owner_id config_name),
  );
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to('user', 'SmokeReports::Schema::Result::User',
			{ 'foreign.id' => 'self.owner_id' });
__PACKAGE__->table('pdc_perf_configs');

1;
