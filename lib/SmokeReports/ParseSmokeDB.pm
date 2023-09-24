package SmokeReports::ParseSmokeDB;
use SmokeReports::Sensible;
use Exporter qw(import);

our @EXPORT_OK = qw(parse_smoke_report);

sub parse_smoke_report {
  my ($result, $report) = @_;

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
  $result->{from_email} = $from || 'unknown';

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

  1;
}

1;
