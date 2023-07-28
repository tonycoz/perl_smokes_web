package SmokeReports::ParsedToDb;
use SmokeReports::Sensible;
use SmokeReports::Dbh;

use Exporter "import";
use SmokeReports::ParseMIME "parse_report";

our @EXPORT_OK = qw(parse_report_to_db parsed_report_to_db);

my @insert_cols = qw(sha subject status os cpu cpu_count cpu_full host compiler body nntp_id from_email error when_at configuration branch duration msg_id logurl);
my $insert_sql = <<SQL;
insert into parsed_reports( sha, subject, status, os, cpu, cpu_count, cpu_full, host, compiler, body, nntp_id, from_email, error, when_at, configuration, branch, duration, msg_id, logurl)
                    values(?,   ?,       ?,      ?,  ?,   ?,         ?,        ?,    ?,        ?,    ?,       ?,          ?,     ?,       ?,             ?,      ?,         ?,      ?)
SQL

sub parse_report_to_db {
    my ($report, $verbose) = @_;

    my $result = parse_report($report->raw_report, $verbose);
    $result->{nntp_id} = $report->nntp_num;
    parsed_report_to_db($result, $verbose);
}

sub parsed_report_to_db {
    my ($parsed, $verbose) = @_;

    my $rs = SmokeReports::Dbh->schema->resultset("ParsedReport");
    $rs->create($parsed);
}

1;
