package Perf::SummarizeDB;
use SmokeReports::Sensible;
use Perf::Summarize qw(perf_summarize);

use Exporter qw(import);

our @EXPORT_OK =
    qw(perf_summarize_db
       perf_summarize_id
       perf_summarize_new
       perf_summarize_updates);

sub perf_summarize_db ($report, $summ = undef) {
    my $summary = perf_summarize($report->json_data);

    my $schema = $report->result_source->schema
	or die;

    require Cpanel::JSON::XS;
    my $enc = Cpanel::JSON::XS->new->canonical(1);
    my %changes =
	(
	 report_id => $report->id,
	 sha => $report->sha,
	 config_id => $report->config_id,
	 needs_update => 0,
	 summary_json => $enc->encode($summary),
	);
    if ($summ) {
	$summ->update(\%changes);
    }
    else {
	my $prss = $schema->resultset("PerfReportSumm");
	$prss->update_or_create(\%changes);
    }
}

sub perf_summarize_id ($schema, $id) {
    my $reports = $schema->resultset("PerfReport");
    my $report = $reports->find({id => $id})
	or return;

    perf_summarize_db($report);
}

sub perf_summarize_new ($schema, $progress) {
    my $reports = $schema->resultset("PerfReport");
    my $query = $reports->search(
	    { 'summary.report_id' => undef },
	    { join => 'summary' }
	);
    my $total_count = 0;
    if ($progress) {
	($total_count) = $query->count;
	$progress->("0 / $total_count\r");
    }
    my $done_count = 0;
    while (my $report = $query->next) {
	perf_summarize_db($report);
	++$done_count;
	$progress->("$done_count / $total_count\r") if $progress;
    }
    $progress->("\n") if $progress;
}

sub perf_summarize_updates ($schema, $progress) {
    my $reports = $schema->resultset("PerfReport");
    my $prss = $schema->resultset("PerfReportSumm");
    my $query = $prss->search(
	{ 'needs_update' => { '!=', 0 } },
	{ 'order_by' => \"report_id desc" },
	);
    my $total_count = 0;
    if ($progress) {
	($total_count) = $query->count;
	$progress->("0 / $total_count\r");
    }
    my $done_count = 0;
    while (my $summ = $query->next) {
	perf_summarize_db($summ->report, $summ);
	++$done_count;
	$progress->("$done_count / $total_count\r") if $progress;
    }
    $progress->("\n") if $progress;
}

1;
