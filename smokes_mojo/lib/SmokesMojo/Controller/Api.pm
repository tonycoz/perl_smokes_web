package SmokesMojo::Controller::Api;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;
use SmokeReports::ParsedToDb "parse_report_to_db";

use Cpanel::JSON::XS;
use IO::Uncompress::Gunzip qw(gunzip);
use IO::Compress::Gzip qw(gzip);
use Digest::SHA qw(sha256_hex);

sub reports_from_id ($self) {
    my $schema = $self->app->schema;
    my $dbr = $schema->resultset("Perl5Smoke");
    my $ids = $dbr->search(
	{
	    report_id => { '>=', $self->param("id") },
	},
	{
	    columns => [ "report_id" ],
	    order_by => "report_id",
	    rows => 100,
	});
    my @ids = map { $_->report_id } $ids->all;

    $self->render(json => \@ids);
}

sub report_data ($self) {
    my $schema = $self->app->schema;
    my $dbr = $schema->resultset("Perl5Smoke");
    my $pr = $dbr->search({ report_id => $self->param("id") })->single;
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $lf = $pr->log_filename($self->app->config);
    if ($lf && -f $lf) {
	my $json = Cpanel::JSON::XS->new->utf8;
	my $dec = $json->decode($pr->raw_report);
	my $data;
	if (gunzip $lf, \$data) {
	    utf8::decode($data);
	    $dec->{log_file} = $data;
	}
	else {
	    $dec->{log_file} = "Could not fetch log";
	}
	$self->render(json => $dec);
    }
    else {
	$self->render(data => $pr->raw_report, format => 'json');
    }
}

sub nntp_from_id ($self) {
    my $schema = $self->app->schema;
    my $dbr = $schema->resultset("DailyBuildReport");
    my $ids = $dbr->search(
        {
	    nntp_num => { '>=', $self->param("id") },
	},
	{
	    columns => [ "nntp_num" ],
	    order_by => "nntp_num",
	    rows => 100,
	});
    my @ids = map { $_->nntp_num } $ids->all;

    $self->render(json => \@ids);
}

sub nntp_data ($self) {
    my $schema = $self->app->schema;
    my $dbr = $schema->resultset("DailyBuildReport");
    my $pr = $dbr->search({ nntp_num => $self->param("id") })->single;
    unless ($pr) {
	return $self->render(template => "does_not_exist");
    }
    $self->render(text => $pr->raw_report, format => "txt");
}

sub _fail_text ($self, $msg) {
    $self->render(format => "text", text => <<EOS);
FAIL
$msg
EOS
}

# Private API used to post NNTP reports received by mail
# I'm subscribed to daily-built-reports, so the reports
# end up in my inbox, this saves having to poll the nntp server
# and means that nntp reports tend to arrive immediately rather
# than waiting for the polling interval.
sub post_report ($self) {
    my $req = $self->req;
    my $msgobj = $req->upload('msg')
	or return $self->_fail_text("Missing msg upload");
    my $time = $req->param('time')
	or return $self->_fail_text("Missing time");
    my $nntp_num = $req->param('nntp_num')
	or return $self->_fail_text("Missing nntp_num");
    my $msg_id = $req->param('msg_id')
	or return $self->_fail_text('Missing msg_id');
    my $hash = $req->param('hash')
	or return $self->_fail_text('Missing hash');
    my $now = time();
    $time >= $now - 60 && $time <= $now + 60
	or return $self->_fail_text('Time out of sync');
    my $msg = $msgobj->asset->slurp;
    my $post_key = $self->app->config->{post_key}
        or die "Missing post_key from config";
    my $myhash = sha256_hex($post_key . $time . $nntp_num . $msg_id . $msg );
    $myhash eq $hash
	or $self->_fail_text('Hash mismatch');
    my $schema = $self->app->schema;
    my $dbrs = $schema->resultset("DailyBuildReport");
    my $report = $dbrs->find({ nntp_num => $nntp_num });
    my $dup = "";
    if ($report) {
	$dup = "Found: " . $report->id;
    }
    else {
        $report = $dbrs->create
	  ({
	    nntp_num => $nntp_num,
	    msg_id => $msg_id,
	    raw_report => $msg,
	   });
    }
    $self->render(format => "text", text => <<EOS);
DONE
$dup
EOS

    parse_report_to_db($report, false);
}

1;
