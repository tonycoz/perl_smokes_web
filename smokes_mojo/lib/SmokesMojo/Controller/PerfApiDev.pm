package SmokesMojo::Controller::PerfApiDev;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;
use Cpanel::JSON::XS ();
use Digest::SHA qw(sha256_hex);
use IO::Compress::Gzip qw(gzip);

our $vNN = "vdev";
our $module = "perf_api_dev";
our $prefix;

# vNN can be vdev which is subject to change
# /api/perf/<vNN>/report/<sha>/ - list of reports for that commit
# /api/perf/<vNN>/report/<sha>/<config-id>/
#  - that report on GET
#  - PUT to store/update report (will require auth)
# /api/perf/<vNN>/configs/
#  - list of configuration names (no user info)

sub register ($class, $aprefix, $routes) {
    $prefix = $aprefix;
  $routes->get("$aprefix/$vNN/report/:sha")->to("$module#report_sha");
  $routes->get("$aprefix/$vNN/report/:sha/:config")->to("$module#report_sha_config");
  $routes->put("$aprefix/$vNN/report/:sha/:config")->to("$module#report_sha_config_put");
  $routes->get("$aprefix/$vNN/summary/:sha/:config")->to("$module#summary_sha_config");
  $routes->get("$aprefix/$vNN/configs")->to("$module#configs");
}

sub report_sha ($self) {
    my $schema = $self->app->schema;
    my $pfr = $schema->resultset("PerfReport");

    my $sha = $self->param("sha");
    my $reps = $pfr->search(
	{ sha => $sha },
	{
	    order_by => "id",
	    columns => [ "id" ],
	    '+select' => [ "config.config_name" ],
	    '+as' => [ "name" ],
	    join => "config",
	});
    my @all = $reps->all;
    unless (@all) {
	# do we know this commit?
	my $crs = $schema->resultset("GitCommit");
	if (!$crs->find({ sha => $sha })) {
	    # no such commit known
	    return $self->reply->not_found;;
	}
    }
    my @data = map {
	+{
	    name => $_->get_column("name"),
	    # FIXME: fill in the prefix
	    url => "$prefix/$vNN/report/$sha/".$_->get_column("name")
	}
    } $reps->all;
    $self->render(json => \@data);
}

sub report_sha_config ($self) {
    my $schema = $self->app->schema;
    my $pfr = $schema->resultset("PerfReport");
    my $cfr = $schema->resultset("PerfConfig");

    my $sha = $self->param("sha");
    my $config_name = $self->param("config");

    my $cf = $cfr->find({ config_name => $config_name })
	or return $self->reply->not_found;

    my $rep = $pfr->find({ config_id => $cf->id, sha => $sha })
	or return $self->reply->not_found;

    my $report_sha = $rep->report_sha;
    if ($self->is_fresh(etag => $report_sha)) {
	return $self->rendered(304);
    }

    $self->res->headers->etag(qq("$report_sha"));
    if ($self->req->headers->accept_encoding =~ /\bgzip\b/) {
	$self->res->headers->content_encoding("gzip");
	$self->render(data => $rep->report_gzip, format => 'json');
    }
    else {
	$self->render(data => $rep->report_json, format => 'json');
    }
}

sub report_sha_config_put ($self) {
    my $schema = $self->app->schema;
    my $cfr = $schema->resultset("PerfConfig");

    my $sha = $self->param("sha");
    my $config_name = $self->param("config");

    my $cf = $cfr->find({ config_name => $config_name })
	or return $self->reply->not_found;

    my $json = $self->req->body;
    eval {
	Cpanel::JSON::XS->new->decode($json);
	1;
    } or return $self->reply->exception("Invalid JSON");

    my $report_sha = sha256_hex($json);
    my $report_gzip;
    gzip(\$json, \$report_gzip, -Level => 9);
    defined $report_gzip or die ;

    # FIXME: more validation

    my $pfr = $schema->resultset("PerfReport");
    my $rec = $pfr->update_or_create(
	{
	    sha => $sha,
	    config_id => $cf->id,
	    report_json => $json,
	    report_gzip => $report_gzip,
	    # FIXME: find a prettier way
	    mod_at => POSIX::strftime("%Y%m%d%H%M%S", gmtime),
	    report_sha => $report_sha,
	});


    # anything special to do here?
    $self->render(json => [ message => "Success" ]);
}

sub summary_sha_config ($self) {
    my $schema = $self->app->schema;
    my $prs = $schema->resultset("PerfReportSumm");
    my $cfr = $schema->resultset("PerfConfig");

    my $sha = $self->param("sha");
    my $config_name = $self->param("config");

    my $cf = $cfr->find({ config_name => $config_name })
	or return $self->reply->not_found;

    my $summ = $prs->find({ config_id => $cf->id, sha => $sha })
	or return $self->reply->not_found;

    $self->render(data => $summ->summary_json, format => 'json');
}

sub configs($self) {
}

1;
