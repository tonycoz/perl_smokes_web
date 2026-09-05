package SmokeReports::ParseSmokeDB;
use SmokeReports::Sensible;
use Exporter qw(import);
use JSON;
use SmokeReports::ParseUtil qw(canonify_config_opts fill_common);

my $json_parser = JSON->new->utf8;

our @EXPORT_OK = qw(parse_smoke_report parse_decoded_smoke_report);

sub base_result() {
  return
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
     conf1_struct => {},
     test_failures_summary => [],
     todo_passed_summary => [],
     parse_warnings => '',
    );
}

sub parse_smoke_report ($report, $verbose) {
  my %result = base_result();
  
  my $pjson;
  unless (eval { $pjson = $json_parser->decode($report); 1 }) {
    $result{error} = "JSON parse error: $@";
  }
  else {
    local $SIG{__WARN__} =
      sub ($msg) {
	$result{parse_warnings} .= $msg;
	print STDERR "$pjson->{id}: $msg";
      };
    if (!eval { do_parse_smoke_report(\%result, $pjson); 1 }) {
      $result{error} = $@;
      print "Error: $@\n" if $verbose;
    }
  }

  return \%result;
}

sub parse_decoded_smoke_report($pjson, $verbose) {
  my %result = base_result();

  if (!eval { do_parse_smoke_report(\%result, $pjson); 1 }) {
    $result{error} = $@;
    print "Error: $@\n" if $verbose;
  }

  \%result;
}

my sub test_summary ($results) {
  my %out;
  for my $test (values $results->%*) {
    my @configs;
    for my $cfg ($test->{configs}->@*) {
      my $args = $cfg->{arguments};
      if ($args =~ s/(^|\s+)DEBUGGING$//) {
	length $args and $args = " $args";
	$args = "-DDEBUGGING$args";
      }
      push @configs,
	join " ", grep length,
	"[".($cfg->{locale} || $cfg->{io_envs}). "]", $args;
    }
    @configs = sort @configs;
    my $entry = $out{$test} ||=
      {
       file => $test->{result}{test},
       messages => [ split /\n/, $test->{result}{extra} ],
       configs => \@configs
      };
  }
  return
    [
     sort { $a->{file} cmp $b->{file} } values %out
    ];	
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
  # %tests{$status}{$somekey} =
  # {
  #   test => $filename,
  #   status => "PASSED" | "FAILED"
  #   extra => $extra # test numbers, error exits etc
  #   configs =>
  #   [
  #     arguments => "-Dwhatever",
  #     io_envs => "perlio",
  #     locale => "en_AU.UTF-8" # or undef
  #   ]
  # }
  my %tests;
  my $index = 0;
  for my $conf ($report->{configs}->@*) {
    $conf1{canonify_config_opts($conf->{arguments})} = $index;
    # NNTP reports don't always include the PERLIO part :/
    if ($conf->{results}) {
      for my $res ($conf->{results}->@*) {
	if ($res->{failures}) {
	  # some versions of Test::Smoke dropped the actual test
	  # report details
	  for my $failure (grep { $_->{failure} || $_->{test} }
			   $res->{failures}->@*) {
	    # newer versions put the test info in the failure key,
	    # older versions have it in the parent key
	    my $f = $failure->{failure} || $failure;
	    use Data::Dumper;
	    for my $k (qw(test status extra)) {
	      print STDERR "$k $report->{id}\n", Dumper($res), "\n" unless defined $f->{$k};
	    }
	    my $key = "$f->{test} ($f->{status} $f->{extra})";
	    $tests{$f->{status}}{$key}{result} =
	      {
	       test => $f->{test},
	       status => $f->{status},
	       extra => $f->{extra},
	      };
	    #print "$conf->{arguments}-$res->{io_envs}\n";
	    #print join("/", keys %$res), "\n";
	    my @args = grep /\S/, $conf->{arguments};
	    push @args, "DEBUGGING" if $conf->{debugging} eq "D";
	    push $tests{$f->{status}}{$key}{configs}->@*,
	      {
	       arguments => "@args",
	       io_envs => $res->{io_env},
	       locale => $res->{locale},
	      };
	  }
	}
      }
    }
    ++$index;
  }
  my @test_failures;
  my @todo_passed;
  for my $which ([ $tests{FAILED} || {}, \@test_failures ],
		 [ $tests{PASSED} || {}, \@todo_passed ]) {
    my ($tests, $save, $save_summ) = @$which;
    for my $key (sort keys %$tests) {
      my @confs = $tests->{$key}{configs}->@*;
      my %entry = $tests->{$key}{result}->%*;
      $entry{configs} =
	[
	 sort { $a->{io_envs} cmp $b->{io_envs} ||
		  ($a->{locale} // "") cmp ($b->{locale} // "") ||
		  $a->{arguments} cmp $b->{arguments} } @confs
	];
      push @$save, \%entry;
    }
  }
  $result->{test_failures} = \@test_failures;
  $result->{test_todo_passed}   = \@todo_passed;

  $result->{test_failures_summary} = test_summary($tests{FAILED});
  $result->{todo_passed_summary} = test_summary($tests{PASSED});

  my @conf1 = sort { $conf1{$a} <=> $conf1{$b} } keys %conf1;
  $result->{conf1} = \@conf1;

  my @failures_summ;
  my @todo_passed_summ;
  


  fill_common($result);

  1;
}

1;
