package SmokesMojo;
use v5.32.0;
use Mojo::Base 'Mojolicious', -signatures;
use Path::Tiny qw(path);
use Mojo::File qw(curfile);
use lib path(curfile())->parent->parent->parent->parent->child("lib")->stringify;
use SmokeReports::Schema;
use SmokeReports::Sensible;
use FindBin;

# This method will run once at server start
sub startup ($self) {

  # Load configuration from config file
    my $config = $self->plugin(JSONConfig => { file => "../smoke.cfg" });
    $self->config($config);

   # die path($FindBin::Bin)->parent->child("templates"), "\n";

    my $path = path($FindBin::Bin)->sibling("templates");
    -d $path or die "$path isn't a directory";
    $self->renderer->paths([ $path ]);

  # Configure the application
    $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('site#index');
    $r->get('/recent/')->to("site#recent");
    $r->get('/changes/')->to("site#changes");
    $r->get('/raw/:id')->to("site#raw");
    $r->get('/db/:id')->to("site#db");  
    $r->get('/dbjson/<id:num>')->to("site#dbjson");  
    $r->get('/dbreportjson/<id:num>')->to("site#dbreportjson");
    $r->get('/dblog/<id:num>')->to("site#dblog");
    $r->get('/dblogtext/<id:num>')->to("site#dblogtext");
    $r->get('/api/reports_from_id/<id:num>')->to("api#reports_from_id");
    $r->get('/api/report_data/<id:num>')->to("api#report_data");
}

sub schema ($self) {
    unless ($self->{_schema}) {
	my $dbc = $self->config->{db};
	$self->{_schema} =
	    SmokeReports::Schema
	    ->connect(@{$dbc}{qw(dsn user password)});
    }

    $self->{_schema};
}

1;
