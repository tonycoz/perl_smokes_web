package SmokesMojo::Controller::Api;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use SmokeReports::Sensible;

use Cpanel::JSON::XS;
use IO::Uncompress::Gunzip qw(gunzip);
use IO::Compress::Gzip qw(gzip);

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
    $schema->storage->debug(1);
    $schema->storage->debugfh(\*STDERR);
    my @ids = map { $_->report_id } $ids->all;
    $schema->storage->debug(0);

    $self->render(json => \@ids);
}

sub report_data ($self) {
    my $schema = $self->app->schema;
    my $dbr = $schema->resultset("Perl5Smoke");
    print STDERR "report ", $self->param("id") ,"\n";
    my $pr = $dbr->search({ report_id => $self->param("id") })->single;
    unless ($pr) {
	$self->render(template => "does_not_exist");
    }
    my $lf = $pr->log_filename($self->app->config);
    if ($lf && -f $lf) {
	print STDERR "Adding log\n";
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
	print STDERR "Just bytes\n";
	$self->render(data => $pr->raw_report, format => 'json');
    }
}

1;
