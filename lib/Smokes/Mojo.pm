package Smokes::Mojo;
use v5.32.0;
use Mojo::Base 'Mojolicious', -signatures;
use Smokes::Schema;
use Smokes::Helpers::Sensible;
use Smokes::Helpers::Dbh;

# This method will run once at server start
sub startup ($self) {

  # Load configuration from config file
    my $config = $self->plugin(JSONConfig => { file => "smoke.cfg" });
    $self->config($config);

  # Configure the application
    $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('site#index');
    $r->get('/latest/')->to("site#latest");
    $r->get('/recent/')->to("site#recent");
    $r->get('/matrix/')->to("site#matrix");
    $r->get('/submatrix/')->to("site#submatrix");
    $r->get('/changes/')->to("site#changes");
    $r->get('/raw/:id')->to("site#raw");
    $r->get('/rawparsedjson/:id')->to("site#rawparsedjson");
    $r->get('/db/:id')->to("site#db");  
    $r->get('/dbjson/<id:num>')->to("site#dbjson");  
    $r->get('/dbreportjson/<id:num>')->to("site#dbreportjson");
    $r->get('/dbparsedjson/<id:num>')->to("site#dbparsedjson");
    $r->get('/dblog/<id:num>')->to("site#dblog");
    $r->get('/dblogtext/<id:num>')->to("site#dblogtext");
    $r->get('/unparsed/groups/')->to("site#unparsed_groups");
    $r->get('/unparsed/')->to("site#unparsed");
    $r->get('/api/reports_from_id/<id:num>')->to("api#reports_from_id");
    $r->get('/api/report_data/<id:num>')->to("api#report_data");
    $r->post('/api/postreport/post')->to("api#post_report");
    $r->get('/api/nntp_from_id/<id:num>')->to("api#nntp_from_id");
    $r->get('/api/nntp_data/<id:num>')->to("api#nntp_data");
}

sub schema ($self) {
    return Smokes::Helpers::Dbh->schema;
}

1;
