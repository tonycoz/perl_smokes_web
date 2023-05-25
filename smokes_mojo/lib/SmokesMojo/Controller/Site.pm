package SmokesMojo::Controller::Site;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;
use Mojo::JSON 'decode_json';

sub index ($self) {
    my $branch = $self->param("b");
    my $start = $self->param("s");
    my $page = $self->param("page");
    defined $page && $page =~ /^[1-9][0-9]*$/ or $page = 1;
    defined $branch or $branch = "blead";
    my $schema = $self->app->schema;
    my $crs = $schema->resultset("GitCommit");
    my $gbrs = $schema->resultset("GitBranch");
    my $prs = $schema->resultset("ParsedReport");
    my $commits;
    if ($start) {
	my $start_commit = $crs->find( { sha => $start } );
	if ($start_commit) {
	    if ($start_commit->branch) {
		$branch = $start_commit->branch;
		$commits = $crs->search(
		    { branch => $branch,
		      ordering => { '<=', $start_commit->ordering }
		    },
		    {
			columns => [ qw(sha subject ordering) ],
			order_by => "ordering DESC",
			rows => 50,
			page => $page,
		    });
	    }
	    else {
		$self->param(b => "blead");
		$self->param(s => undef);
		$self->stash(message => qq("$start" branch not found));
		return $self->index;
	    }
	}
	else {
	    $self->param(b => "blead");
	    $self->param(s => undef);
	    $self->stash(message => qq(Unknown commit "$start"));
	    return $self->index;
	}
    }
    else {
	$commits = $crs->search(
	    { branch => $branch },
	    {
		columns => [ qw(sha subject ordering) ],
		order_by => "ordering DESC",
		rows => 50,
		page => $page,
	    });
    }
    my @commits;
    while (my $commit = $commits->next) {
	push @commits,
	{
	    sha => $commit->sha,
	    subject => $commit->subject,
	    ordering => $commit->ordering,
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
    for my $commit (@commits) {
	for my $smoke ($commit->{smokes}->@*) {
	    my %s = (
		$smoke->get_columns,
		map { $_ => $smoke->$_ }
		qw(from original_url report_url)
		);
	    $s{logurl} = $smoke->more_logurl($self->app->config);
	    $smoke = \%s;
	}
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
		  branch => $branch,
	          message => $self->stash("message"),
		  branches => $branches,
		  start => $start,
		  page => $page,
		  more_pages => (@commits == 50),
	);
}

sub recent ($self) {
    my $page = $self->param("page");
    defined $page && $page =~ /^[1-9][0-9]*$/
	or $page = 1;

    my $schema = $self->app->schema;
    my $prs = $schema->resultset("ParsedReport");
    my $smokes = $prs->search
	({
	    
	 },
	 {
	     columns =>
		 [
		  qw(id status os cpu cpu_count cpu_full host
		     compiler from_email),
#		  #{ "age" => \  },
		  qw(msg_id configuration sha
		     smokedb_id nntp_id logurl),
		 ],
	     '+select' =>
		 [
		  \ "timediff(now(), when_at)",
		  "commit.branch",
		  "commit.subject",
		 ],
	     '+as' => [
		 "age",
		 "branch",
		 "subject",
		 ],
	     join => 'commit',
	     rows => 100,
	     page => $page,
	     order_by => { -desc => "when_at" },
	 });
    $schema->storage->debug(1);
    $schema->storage->debugfh(\*STDERR);
    my @smokes = $smokes->all;
    $schema->storage->debug(0);
    for my $smoke (@smokes) {
	my %temp = (
	    $smoke->get_columns,
	    map { $_ => $smoke->$_ }
	    qw(from original_url report_url)
	    );
	$temp{logurl} = $smoke->more_logurl($self->app->config);
	$smoke = \%temp;
    }
    $self->render(page => $page,
                  smokes => \@smokes);
}

# display the stored NNTP/mail report
# most headers are removed
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

# display a formatted version of the stored smoke DB report
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
		  id => $sr->report_id,
		  logurl => $pr->more_logurl($self->app->config));
}

# display the raw report JSON as locally stored
# the only explicit change is the log_file content
# is removed, but decoding/encoding may also
# make minor changes
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

# display the report JSON with the data structure as transformed
# for use in producing the report
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

sub dblog ($self) {
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
    my $base = $self->app->config->{logpath};
    unless (-f $base . "/" . $pr->smokedb_id . ".gz") {
	$self->render(template => "does_not_exist");
    }
    
    $self->render(pr => $pr,
		  sr => $sr,
		  id => $sr->report_id);
}

sub dblogtext ($self) {
    my $report_id = $self->param("id");
    my $schema = $self->app->schema;
    my $dbr = $schema->resultset("Perl5Smoke");
    my $sr = $dbr->find({ report_id => $report_id });
    unless ($sr) {
	$self->render(template => "does_not_exist");
    }
    my $base = $self->app->config->{logpath};
    my $filename = $base . "/" . $sr->report_id . ".gz";
    unless (-f $filename) {
	$self->render(template => "does_not_exist");
    }

    if ($self->req->headers->accept_encoding =~ /\bgzip\b/) {
	$self->res->headers->content_encoding("gzip");
	$self->res->headers->content_type("text/plain; charset=utf-8");
	$self->reply->file($filename);
    }
    else {
	$self->render(text => <<'TEXT');
Let tonyc know about your old browser.
He was lazy and only supported browsers with gzip support.
TEXT
    }
}
1;
