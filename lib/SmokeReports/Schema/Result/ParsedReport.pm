package SmokeReports::Schema::Result::ParsedReport;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table('parsed_reports');
__PACKAGE__->add_columns
  (
   id =>
   {
    is_auto_increment => 1,
    data_type => "integer",
   },
   qw/sha subject status os cpu cpu_count cpu_full/,
   qw/host compiler body/,
   nntp_id => {
       data_type => "integer",
       default => undef,
   },
   qw/from_email error/,
   qw/when_at configuration branch duration/,
   smokedb_id => {
       data_type => "integer",
       default => undef,
   },
   qw/logurl msg_id uuid/,
   need_update => {
       data_type => "integer",
       default => 0,
   },
   qw(config_hash build_hash));
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to('commit', 'SmokeReports::Schema::Result::GitCommit',
			{ 'foreign.sha' => 'self.sha' });
__PACKAGE__->belongs_to('nntp', 'SmokeReports::Schema::Result::DailyBuildReport',
			{ 'foreign.nntp_num' => 'self.nntp_id' });
__PACKAGE__->belongs_to('smokedb', 'SmokeReports::Schema::Result::Perl5Smoke',
			{ 'foreign.report_id' => 'self.smokedb_id' });

sub from ($self) {
    my $from = $self->from_email;
    $from =~ s/\@/ # /;

    $from;
}

sub original_url ($self) {
    my $msg_id = $self->msg_id;
    if ($msg_id) {
	$msg_id =~ s/^<//;
	$msg_id =~ s/>$//;
	return "http://www.nntp.perl.org/group/perl.daily-build.reports/;msgid=$msg_id";
    }
    else {
	return "https://perl5.test-smoke.org/report/" . $self->smokedb_id;
    }
}

sub report_url ($self) {
    if ($self->msg_id) {
	return "/raw/" . $self->nntp_id;
    }
    else {
	return "/db/" . $self->smokedb_id;
    }
}

sub more_logurl ($self, $config) {
    $self->logurl and return $self->logurl;
    my $base = $config->{logpath};
    $base or die;
    my $id = $self->smokedb_id;
    $id or return '';
    -f "$base/$id.gz" or return '';
    return "/dblog/$id";
}

sub insert_columns($self) {
    grep !/^(?:id|need_update)$/, $self->columns;
}

sub update_columns($self) {
    grep !/^(?:nntp_id|smokedb_id)$/, $self->insert_columns;
}

1;
