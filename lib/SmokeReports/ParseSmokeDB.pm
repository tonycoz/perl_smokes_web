package SmokeReports::ParseSmokeDB;
use SmokeReports::Sensible;
use Exporter qw(import);
use JSON;
use SmokeReports::ParseUtil qw(canonify_config_opts fill_correlations);

my $json_parser = JSON->new->utf8;

our @EXPORT_OK = qw(parse_smoke_report);

sub parse_smoke_report ($report, $verbose) {
  my %result =
    (
       sha => "",
       subject => "",
       status => "",
       os => "",
       cpu => "",
       cpu_count => 0,
       cpu_full => "",
       host => "",
       compiler => "",
       body => "",
       from_email => "",
       error => "",
       configuration => undef,
       branch => undef,
       duration => 0,
       msg_id => undef,
       build_hash => '',
       config_hash => '',
    );

  my $pjson;
  unless (eval { $pjson = $json_parser->decode($report); 1 }) {
    $result{error} = "JSON parse error: $@";
  }
  elsif (!eval { do_parse_smoke_report(\%result, $pjson); 1 }) {
    $result{error} = $@;
    print "Error: $@\n" if $verbose;
  }

  \%result;
}

sub do_parse_smoke_report ($result, $report) {
  $result->{sha} = $report->{git_id};

  $result->{status} = $report->{summary};
  $result->{os} = "$report->{osname} $report->{osversion}";
  $result->{cpu} = $report->{architecture};
  $result->{cpu_count} = $report->{cpu_count};
  $result->{cpu_count} =~ /^[1-9][0-9]*$/ or $result->{cpu_count} = 0;
  $result->{cpu_full} = $report->{cpu_description};
  $result->{host} = $report->{hostname};
  my $cfg0 = $report->{configs}[0];
  $result->{compiler} = "$cfg0->{cc} $cfg0->{ccversion}";
  $result->{body} = "";
  my $from = $report->{reporter};
  if ($from && $from =~ /([a-z0-9.-]+\@[a-z0-9-.]+)/i) {
    $from = $1;
  }
  $result->{from_email} = $from || $report->{username} || 'unknown';

  $result->{duration} = $report->{duration};

  if ($report->{user_note}) {
    my %notes;
    for my $entry (grep /:/, split /\n/, $report->{user_note}) {
      my ($key, $val) = split /:\s*/, $entry, 2;
      $notes{$key} = $val;
    }

    $result->{configuration} = $notes{Config};
    $result->{branch} = $notes{Branch};
    $result->{uuid} = $notes{UUID};
  }

  # lie
  $result->{subject} = "Smoke [unknown] $report->{summary} $report->{osname} $report->{osversion} ($report->{architecture}/$report->{cpu_count} cpu)";

  my %conf1;
  #my %conf2;
  my $index = 0;
  for my $conf ($report->{configs}->@*) {
    $conf1{canonify_config_opts($conf->{arguments})} = $index;
    # NNTP reports don't always include the PERLIO part :/
    #my @opts;
    #push @opts, "PERL
    #$conf2{$conf->{}} = $conf->{index};
    ++$index;
  }
  my @conf1 = sort { $conf1{$a} <=> $conf1{$b} } keys %conf1;
  $result->{conf1} = \@conf1;

  fill_correlations($result);

  1;
}

1;
