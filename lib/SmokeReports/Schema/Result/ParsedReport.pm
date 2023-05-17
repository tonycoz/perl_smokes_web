package SmokeReports::Schema::Result::ParsedReport;
use v5.32.0;
use parent qw/DBIx::Class::Core/;
use SmokeReports::Sensible;

__PACKAGE__->table('parsed_reports');
__PACKAGE__->add_columns(qw/id sha subject status os cpu cpu_count cpu_full/,
			 qw/host compiler body nntp_id from_email error/,
			 qw/when_at configuration branch duration/,
			 qw/smokedb_id logurl msg_id uuid/);
__PACKAGE__->set_primary_key("id");

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

1;
