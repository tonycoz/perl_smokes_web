package SmokesMojo::Controller::Site;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;

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
			columns => [ qw(id sha subject ordering seen_at parent_id) ],
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
		columns => [ qw(id sha subject ordering parent_id seen_at) ],
		order_by => "ordering DESC",
		rows => 50,
		page => $page,
	    });
    }
    my @commits;
    while (my $commit = $commits->next) {
	push @commits,
	{
	    id => $commit->id,
	    sha => $commit->sha,
	    subject => $commit->subject,
	    ordering => $commit->ordering,
	    seen_at => $commit->seen_at,
	    parent_id => $commit->parent_id,
	    smokes => [
		$prs->search({sha => $commit->sha},
			     { order_by => [ "os", "host", "id" ] })
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

    my %work_commits = map { $_->{id} => $_ } @commits;
    my %commits = %work_commits;
    my %parents = map { $_->{parent_id} => $_->{id} } @commits;
    my @work;
    my @groups;
    while (%work_commits) {
	my @check = sort {
	    $b->{seen_at} cmp $a->{seen_at} ||
		$b->{ordering} <=> $a->{ordering}
	} values %work_commits;
	my $latest_seen = $check[0]{seen_at};
	my $latest = $check[0];
	push @groups, +{
	    commits => [ $latest ],
	    seen_at => $latest->{seen_at},
	};
	push @work, $latest;
	delete $work_commits{$latest->{id}};
	while ($work_commits{$latest->{parent_id}}) {
	    $latest = $work_commits{$latest->{parent_id}};
	    delete $work_commits{$latest->{id}};
	    push @work, $latest;
	    push $groups[-1]{commits}->@*, $latest;
	}
    }
    @commits = @work;
    for my $commit (@commits) {
	my $parent = $commits{$commit->{parent_id}};
	$commit->{parent_sha} = $parent ? $parent->{sha} : "";
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
    # we want blead and latest maint at the top, and then the
    # selected branch if it's neither of those
    my @last_maint = (sort grep /^maint-5.[0-9]{2}$/, @$branches)[-1, -2];
    my @branches = ( "blead", @last_maint );
    my %bseen = map { $_ => 1 } @branches;
    unless ($bseen{$branch}) {
	push @branches, $branch;
	++$bseen{$branch};
    }
    push @branches, grep !$bseen{$_}, @$branches;

    $self->render(commits => \@commits,
		  groups => \@groups,
		  branch => $branch,
	          message => $self->stash("message"),
		  branches => \@branches,
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
    my @smokes = $smokes->all;
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
	my @raw_headers = split /\n/, $headers;
	my @headers;
	for my $raw_header (@raw_headers) {
	    if (!@headers || $raw_header !~ /^\s/) {
		push @headers, $raw_header;
	    }
	    else {
		$headers[-1] .= $raw_header;
	    }
	}
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
    my $pr = $prs->find(
	{ smokedb_id => $report_id },
	{
	    columns => [ qw(subject smokedb_id) ]
	});
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $base = $self->app->config->{logpath};
    unless (-f $base . "/" . $pr->smokedb_id . ".gz") {
	$self->render(template => "does_not_exist");
    }
    
    $self->render(pr => $pr,
		  id => $pr->smokedb_id);
}

sub dblogtext ($self) {
    my $report_id = $self->param("id");
    unless ($report_id =~ /\A[1-9][0-9]*\z/) {
	$self->render(template => "does_not_exist");
    }
    my $base = $self->app->config->{logpath};
    my $filename = $base . "/" . $report_id . ".gz";
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

sub changes ($self) {
    $self->render();
}

1;
