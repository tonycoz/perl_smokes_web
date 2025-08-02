package SmokesMojo::Controller::Perf;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;

# FIXME: de-dupe

sub _branches ($self, $current) {
    my $schema = $self->app->schema;
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
    if ($current && !$bseen{$current}) {
	push @branches, $current;
	++$bseen{$current};
    }
    push @branches, grep !$bseen{$_}, @$branches;

    \@branches;
}

sub _commits ($self, $branch) {
    my $schema = $self->app->schema;
    my $crs = $schema->resultset("GitCommit");
    my $gbrs = $schema->resultset("GitBranch");
    my $prs = $schema->resultset("PerfReport");
    my $commits;
    {
	$commits = $crs->search(
	    { branch => $branch },
	    {
		columns => [ qw(id sha subject ordering parent_id seen_at) ],
		order_by => "ordering DESC",
		rows => 50,
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
	    reports => [
		$prs->search({sha => $commit->sha},
			     {
				 columns => [],
			      '+select' => [ "config.config_name" ],
				  '+as' => [ "config_name" ],
				  join => "config",
			     })
		],
	};
    }
    if (!@commits) {
	$self->param(b => "blead");
	$self->stash(message => qq(Branch "$branch" has no unique commits));
	return;
    }

    # FIXME: add commits off the tail of this list

    for my $commit (@commits) {
	for my $report ($commit->{reports}->@*) {
	    $report = +{ $report->get_inflated_columns };
	    $report->{url} = "/api/perf/vdev/report/$commit->{sha}/$report->{config_name}";
	}
    }

    return
	(
	 \@commits
	);
}

sub index ($self) {
    my $branches = $self->_branches("blead");

    $self->render(message => $self->stash("message"),
		  branches => $branches
	);
}

sub branch ($self) {
    my $branch = $self->param("b");
    defined $branch or $branch = "blead";
    my $branches = $self->_branches($branch);

    my ($commits) = $self->_commits($branch);
    $commits
	or return $self->index;

    $self->render(commits => $commits,
		  branch => $branch,
	          message => $self->stash("message"),
		  branches => $branches,
	);
}

1;
