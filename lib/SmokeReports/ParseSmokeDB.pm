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
    );
}

sub parse_smoke_report ($report, $verbose) {
  my %result = base_result();
  my $pjson;
  unless (eval { $pjson = $json_parser->decode($report); 1 }) {
    $result{error} = "JSON parse error: $@";
  }
  elsif (!eval { do_parse_smoke_report(\%result, $pjson); 1 }) {
    $result{error} = $@;
    print "Error: $@\n" if $verbose;
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
  my %tests;
  my $index = 0;
  for my $conf ($report->{configs}->@*) {
    $conf1{canonify_config_opts($conf->{arguments})} = $index;
    # NNTP reports don't always include the PERLIO part :/
    if ($conf->{results}) {
      for my $res ($conf->{results}->@*) {
	if ($res->{failures}) {
	  for my $failure ($res->{failures}->@*) {
	    my $f = $failure->{failure};
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
		 [ $tests{PASSED} || {}, \@todo_passed   ]) {
    my ($tests, $save) = @$which;
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

  my @conf1 = sort { $conf1{$a} <=> $conf1{$b} } keys %conf1;
  $result->{conf1} = \@conf1;

  fill_common($result);

  1;
}

1;
