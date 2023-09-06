package SmokeReports::ParsedToDb;
use SmokeReports::Sensible;
use SmokeReports::Dbh;

use Exporter "import";
use SmokeReports::ParseMIME "parse_report";

our @EXPORT_OK = qw(parse_report_to_db parsed_report_to_db
		    parse_new_reports_to_db);

sub parse_report_to_db($report, $verbose) {
    my $result = parse_report($report->raw_report, $verbose);
    $result->{nntp_id} = $report->nntp_num;
    parsed_report_to_db($result, $verbose);
}

sub parsed_report_to_db($parsed, $verbose) {
    my $rs = SmokeReports::Dbh->schema->resultset("ParsedReport");
    $rs->create($parsed);
}

sub parse_new_reports_to_db($verbose) {
    my $schema = SmokeReports::Dbh->schema;

    my $reports = $schema->resultset('DailyBuildReport');

    my $query = $reports->search
	(
	 { 'parsed_report.nntp_id' => undef },
	 { join => 'parsed_report' }
	);

    my $total_count;
    if ($verbose) {
	($total_count) = $query->count;
	print "0 / $total_count\r";
    }

    my $done_count = 0;
    while (my $report = $query->next) {
	parse_report_to_db($report, $verbose);
	++$done_count;
	if ($verbose) {
	    print "$done_count / $total_count\r";
	}
    }
    print "\n" if $verbose;
}

1;
