package Perf::Summarize;
use SmokeReports::Sensible;
use Exporter qw(import);
use List::Util qw(min max);

our @EXPORT_OK = qw(perf_summarize);

sub _median ($vals) {
  # the arrays should be fairly small, so I expect this
  # to be faster than trying to partition in perl code
  my @sorted = sort { $a <=> $b } @$vals;
  if (@sorted % 2) {
    return $sorted[int(@sorted/2)];
  }
  else {
    my $first = int(@sorted/2);
    return +($sorted[$first] + $sorted[$first+1])/2;
  }
}

# take a performance report, already decoded from JSON
# and make a summary structure
# layout:
#  {
#    config => same as report
#    system => same as report
#    version => (from report.benchmark.version)
#    benchkeys => [ "branches", ... ], # keys from results.*.result0
#    results => { $benchname => [ medianbranches, median ... ], ... }
#  }
sub perf_summarize ($report) {
  my %out =
    (
     config => $report->{config},
     system => $report->{system},
     version => $report->{benchmark}{version},
    );
  my $results = $report->{benchmark}{results};
  #print "results $results\n";
  my ($key0) = each %$results;
  #print "key0 $key0\n";
  my @benchkeys = sort keys $results->{$key0}{result0}->%*;
  #print "benchkeys @benchkeys\n";
  my %summary;
  for my $result_key (keys %$results) {
    #print "key $result_key\n";
    my $bench = $results->{$result_key};
    my @median;
    my @min;
    my @max;
    for my $key (@benchkeys) {
      my $result0 = _median($bench->{result0}{$key});
      my $result1 = _median($bench->{result1}{$key});
      push @median, $result1 - $result0;
      push @min, min($bench->{result1}{$key}->@*)
	- max($bench->{result0}{$key}->@*);
      push @max, max($bench->{result1}{$key}->@*)
	- min($bench->{result0}{$key}->@*);
    }
    $summary{$result_key} =
      {
       median => \@median,
       min => \@min,
       max => \@max,
      };
  }
  $out{results} = \%summary;
  $out{benchkeys} = \@benchkeys;

  \%out;
}


1;
