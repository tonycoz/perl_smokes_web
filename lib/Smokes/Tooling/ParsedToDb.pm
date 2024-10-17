package Smokes::Tooling::ParsedToDb;
use Smokes::Helpers::Sensible;
use Smokes::Helpers::Dbh;

use Exporter "import";
use Smokes::Tooling::ParseMIME "parse_report";

our @EXPORT_OK = qw(parse_report_to_db parsed_report_to_db
		    parse_new_reports_to_db parse_updates_to_db
		    reparse_ids_to_db);

sub parse_report_to_db($report, $verbose) {
    my $result = parse_report($report->raw_report, $verbose);
    $result->{nntp_id} = $report->nntp_num;
    parsed_report_to_db($result, $verbose);
}

sub parsed_report_to_db($parsed, $verbose) {
    my $rs = Smokes::Helpers::Dbh->schema->resultset("ParsedReport");
    my @insert_cols = $rs->insert_columns;
    my %insert;
    @insert{@insert_cols} = @$parsed{@insert_cols};
    $rs->create(\%insert);
}

sub parse_new_reports_to_db($verbose) {
    my $schema = Smokes::Helpers::Dbh->schema;

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

sub update_report_to_db($nntp_report, $parsed_report, $verbose) {
    my $result = parse_report($nntp_report->raw_report, $verbose);
    if ($result->{error} && $verbose) {
	print "Error ", $nntp_report->nntp_num, ": $result->{error}\n";
    }
    my $schema = Smokes::Helpers::Dbh->schema;
    my $pr = $schema->resultset('ParsedReport');
    my @update_cols = $pr->update_columns;
    my %update;
    @update{@update_cols} = @$result{@update_cols};
    $update{need_update} = 0;
    $parsed_report->update(\%update);
}

sub parse_updates_to_db($verbose) {
    my $schema = Smokes::Helpers::Dbh->schema;
    my $dbr = $schema->resultset('DailyBuildReport');
    my $pr = $schema->resultset('ParsedReport');

    my $query = $pr->search(
	{
	    need_update => { '!=', 0 },
	    nntp_id     => { '!=', undef },
	},
	{ order_by => \"nntp_id desc" }
	);
    my $total_count;
    if ($verbose) {
	$total_count = $query->count;
	print "0 / $total_count\r";
    }

    my $done_count = 0;
    while (my $parsed = $query->next) {
	my $nntp = $parsed->nntp;
	if ($nntp) {
	    update_report_to_db($nntp, $parsed, $verbose);
	}
	else {
	    print "No nntp report ",$parsed->nntp_id, " found for parsed report ",$parsed->id,"\n";
	}
	++$done_count;
	print "$done_count / $total_count\r" if $verbose;
    }
    print "\n" if $verbose;
}

sub reparse_ids_to_db($verbose, $ids) {
    my $schema = Smokes::Helpers::Dbh->schema;
    my $dbr = $schema->resultset('DailyBuildReport');
    my $pr = $schema->resultset('ParsedReport');
    for my $id (@$ids) {
        my $nntp = $dbr->find({ nntp_num => $id })
	  or die "Cannot find parsed NNTP report $id\n";
	my $parsed = $pr->find({ nntp_id => $id });
	update_report_to_db($nntp, $parsed, $verbose);
    }
}

1;
