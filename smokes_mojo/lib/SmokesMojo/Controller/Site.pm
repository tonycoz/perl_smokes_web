package SmokesMojo::Controller::Site;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;
use Mojo::JSON 'decode_json';

sub index ($self) {
    my $branch = $self->param("b");
    defined $branch or $branch = "blead";
    my $schema = $self->app->schema;
    my $crs = $schema->resultset("GitCommit");
    my $gbrs = $schema->resultset("GitBranch");
    my $prs = $schema->resultset("ParsedReport");
    my $commits = $crs->search(
	{ branch => $branch },
	{
	    columns => [ qw(sha subject) ],
	    order_by => "ordering DESC",
	    rows => 50
	});
    my @commits;
    while (my $commit = $commits->next) {
	push @commits,
	{
	    sha => $commit->sha,
	    subject => $commit->subject,
	    smokes => [
		$prs->search({sha => $commit->sha},
			     { order_by => "os" })
		],
	};
    }
    if (!@commits) {
	$self->param(b => "blead");
	$self->stash(message => qq(Unknown branch "$branch"));
	return $self->index;
    }
    my $branches = $schema->storage->dbh_do
	(
	 sub {
	     my ($storage, $dbh) = @_;
	     $dbh->selectcol_arrayref(<<'SQL')
select distinct b.name
from git_branches b
order by
  (select max(seen_at)
   from git_commits c
   where c.branch = b.name) desc
SQL
	 }
	);
    
    $self->render(commits => \@commits,
		  branch => "blead",
	          message => $self->stash("message"),
		  branches => $branches);
}

sub raw ($self) {
    my $nntp_id = $self->param("id");
    my $schema = $self->app->schema;
    my $prs = $schema->resultset("ParsedReport");
    my $dbrs = $schema->resultset("DailyBuildReport");
    my $pr = $prs->find({ nntp_id => $nntp_id });
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $r = $dbrs->find({ nntp_num => $nntp_id },
			{ columns => "raw_report" });
    if ($r) {
	my $raw = $r->raw_report;
	$raw =~ tr/\r//d;
	my ($headers, $body) = split /\n\n/, $raw, 2;
	my @headers = split /\n/, $headers;
	@headers = grep /^(?:subject|message-id|content-type|mime-version|date|content-transfer-encoding|content-type):/i, @headers;
	my $non_raw = join("\n", @headers) . "\n\n" . $body;
	return $self->render(raw => $non_raw,
			     pr => $pr,
			     id => $nntp_id);
    }
    else {
	$self->render(template => "does_not_exist");
    }
}

sub db ($self) {
    my $report_id = $self->param("id");
    my $schema = $self->app->schema;
    my $prs = $schema->resultset("ParsedReport");
    my $dbr = $schema->resultset("Perl5Smoke");
    my $pr = $prs->find({ smokedb_id => $report_id });
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $sr = $dbr->find({ report_id => $report_id });
    unless ($sr) {
	$self->render(template => "does_not_exist");
    }
    
    my $js = $sr->full_report;
    $self->render(js => $js,
		  pr => $pr,
		  sr => $sr,
		  id => $sr->report_id);
}

sub dbjson ($self) {
    my $report_id = $self->param("id");
    my $schema = $self->app->schema;
    my $prs = $schema->resultset("ParsedReport");
    my $dbr = $schema->resultset("Perl5Smoke");
    my $pr = $prs->find({ smokedb_id => $report_id });
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $sr = $dbr->find({ report_id => $report_id });
    unless ($sr) {
	$self->render(template => "does_not_exist");
    }
    require Cpanel::JSON::XS;
    my $data = $sr->raw_report;
    $self->render(data => $data, format => "json");
}

sub dbreportjson ($self) {
    my $report_id = $self->param("id");
    my $schema = $self->app->schema;
    my $prs = $schema->resultset("ParsedReport");
    my $dbr = $schema->resultset("Perl5Smoke");
    my $pr = $prs->find({ smokedb_id => $report_id });
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $sr = $dbr->find({ report_id => $report_id });
    unless ($sr) {
	$self->render(template => "does_not_exist");
    }
    require Cpanel::JSON::XS;
    my $data = Cpanel::JSON::XS->new->utf8->encode($sr->full_report);
    $self->render(data => $data, format => "json");
}

1;
