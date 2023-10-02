package SmokeReports::ParseMIME;
use strict;
use Exporter qw(import);
use MIME::Parser;
use DateTime::Format::Mail;
use SmokeReports::Sensible;
use SmokeReports::ParseUtil qw(canonify_config_opts fill_correlations);

our $VERSION = "1.001";

our @EXPORT_OK = qw(parse_report);

my $date_parser = DateTime::Format::Mail->new;
$date_parser->loose;

my $parser;

{
    my $parser;
    sub _parser {
	unless ($parser) {
	    $parser = MIME::Parser->new;
	    $parser->output_to_core(1);
	}

	$parser;
    }
}

sub parse_report($report_data, $verbose) {

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
       when_at => undef,
       configuration => undef,
       branch => undef,
       duration => 0,
       msg_id => undef,
      );
    eval {
      _process_report(\%result, $report_data);
      1;
    } or do {
      $result{error} = $@;
    };

    \%result;
}

sub _process_report($result, $report_data) {
  my $entity = _parser()->parse_data($report_data);
  my $head = $entity->head;
  my $bh = $entity->bodyhandle;
  my @body;
  if ($bh) {
    @body = $bh->as_lines;
  }
  else {
    my @parts = $entity->parts;
  PARTS:
    for my $part (@parts) {
      my $ph = $part->head;
      $ph->unfold;
      my $ct = $part->effective_type;
      if ($ct && $ct =~ m(^text/plain\b)i) {
	@body = $part->bodyhandle->as_lines;
	last PARTS;
      }
    }
    unless (@body) {
      die "No body text found\n";
    }
  }
  $result->{body} = join '', @body;

  $head->unfold;
  my $subject = $entity->get("Subject");
  chomp $subject;
  $result->{subject} = $subject;
  my $from = $entity->get("From");
  chomp $from;
  if ($from =~ /([a-z0-9.-]+\@[a-z0-9-.]+)/i) {
    $result->{from_email} = $1;
  }

  my $date = $entity->get("Date");
  if ($date) {
    my $date_parsed;
    eval {
      $date_parsed = $date_parser->parse_datetime($date);
      $date_parsed->set_time_zone("UTC");
    };
    $result->{when_at} = $date_parsed;
  }

  $result->{msg_id} = $entity->get('Message-Id')
      or die "No Message-Id header found\n";
  chomp($result->{msg_id});

  my ($v, $status, $os, $cpu, $cpu_count, $cores, $cfg) =
    $subject =~ /^Smoke \[([0-9.a-zA-Z_\/!\+-]*)\] \S+ (PASS(?:-so-far)?|FAIL\(.+\)) (.*)\s\((.*)\/(?:([0-9]+) cpu(?:\[([0-9]+) cores\])?)?\)(?:\s+\{([^\{\}]+)\})?\s*$/
      or die "Cannot parse subject\n$subject\n";
  $result->{status} = $status;
  $result->{os} = $os;
  $result->{cpu} = $cpu;
  $cfg and $result->{configuration} = $cfg;
  $cores ||= 1;
  defined $cpu_count or $cpu_count = 1;
  defined $cores or $cores = 1;
  $result->{cpu_count} = $cpu_count * $cores;

  @body = map {; $_ // "" } @body;
  chomp @body;
  tr/\r//d for @body;
  pop @body while @body && $body[-1] !~ /\S/;
  # George Greer links the reports at the front
  if (@body && $body[0] =~ /\bSmoke logs available at (\S+)$/) {
    $result->{logurl} = $1;
  }
  # some reports get stuff added at the front, scan for the prologue
  while (@body && $body[0] !~ /^\s*Automated smoke report /) {
    shift @body;
  }
  @body
    or die "No report prologue found in body\n";

  if ($body[0] =~ /^(\s+)/) {
    # some old rocket software reports have a space before each line
    my $leading = $1;
    s/^$leading// for @body;
  }

  # first line should be an intro
  my $first = shift @body;
  my ($sha) = $first =~ /^Automated smoke report for (?:branch [\w.\\\/+-]+ )?[0-9.]+ patch ([0-9a-f]+)/
    or die "Cannot parse SHA from '$first'\n";
  $result->{sha} = $sha;
  # the os390 reports include a describe line before the host line
  # so skip looking for a host line
  while (@body && $body[0] !~ /^([a-z.0-9-]+):\s*(.*)/i) {
    shift @body;
  }
  my $host_line = shift @body
    or die "No host line\n";

  my ($host, $cpu_full) = $host_line =~ /^([a-z.0-9-]+):\s*(.*)/i
    or die "Cannot parse host line:\n$host_line\n";
  $result->{host} = $host;
  $result->{cpu_full} = $cpu_full;

  my $os_line = shift @body
    or die "No os line\n";
  $os_line =~ /^\s+on\s+(.*?) - (.*)/
    or die "Cannot parse os line\n$os_line\n";
  $result->{osname} = $1;
  $result->{osversion} = $2;
  my $os1 = "$1 $2";
  $result->{os} = $os1; # more reliable than subject

  my @cc;
  while (@body && $body[0] =~ /^\s+using\s+(\S(?:.*\S)?)\s+version(.*)/) {
    my ($cmd, $ver) = ($1, $2);
    $ver =~ s/^\s+//;
    my $num = 1;
    if ($ver =~ s/ \(\*(\d+)\)\s*$//) {
      $num = $1;
    }
    push @cc, { cc => $cmd, version => $ver, index => $num };
    shift @body;
  }
  unless (@cc) {
    # some reports don't have the " version " so guess
    if (@body && $body[0] =~ /^\s+using\s+(.*?) ([a-z]\d\.\d+.*)/i) {
      push @cc, { cc => $1, version => $2, index => 1 };
      shift @body;
    }
  }
  unless (@cc) {
    my $line = @body ? $body[0] : "<no line>";
    die "No compiler lines seen\n$line\n";
  }
  $result->{compiler} = "$cc[0]{cc} $cc[0]{version}";

  # some old openvms reports have a blank line before the smoketime
  # like 220979
  while (@body && $body[0] !~ /\S/) {
    shift @body;
  }
  my ($day, $hour, $minute) = ( 0, 0, 0 );
  if (@body && $body[0] =~ /^\s+smoketime
                            (?:\s+(\d+)\ days?)?
			    (?:\s+(\d+)\ hours?)?
			    (?:\s+(\d+)\ minutes?)?
			   /x) { # ignore any seconds
    ($day, $hour, $minute) = ( $1, $2, $3 );
    $day    ||= 0;
    $hour   ||= 0;
    $minute ||= 0;
    shift @body;
  }
  else {
    die "Could not parse smoketime\n", _escape($body[0]), "\n";
  }
  $result->{duration} = $day * 86_400 + $hour * 3600 + $minute * 60;

  # look for the summary
  while (@body && $body[0] !~ /^Summary:/) {
      shift @body;
  }
  if (@body) {
    $body[0] =~ /^Summary:\s+(.*)$/
      or die "Summary line not parsable\n$body[0]\n";
    unless ($result->{status} eq $1) {
      my $summ_esc = _escape($1);
      my $subj_esc = _escape($result->{status});

      die <<DIE;
Status from summary line doesn't match subject:
'$summ_esc' vs '$subj_esc'
$body[0]
$subject
DIE
    }
    shift @body;
  }

  my $conf_re = qr/^.*\s+Configuration\s+\(common\)\s*(.*)/;
  while (@body && $body[0] !~ $conf_re) {
    shift @body;
  }
  @body && $body[0] =~ $conf_re
    or die "No 'Configuration' line found\n";
  my $common = $1 // "";
  $common eq "none" and $common = "";
  $common =~/\S/ and $common .= " ";
  shift @body;
  @body && $body[0] =~ /^\s*-+\s+-+$/
    or die "No build matrix header found\n";
  shift @body;
  my @conf1;
  while (@body && $body[0] =~ /^(?:[OFX?-cmMt]\s+)+(.*)$/) {
    push @conf1, canonify_config_opts("$common$1");
    shift @body;
  }
  s/\s+$// for @conf1;
  my @conf2;
  while (@body && $body[0] =~ /^(?:\|\s+)*\+-+\s+(.*)/) {
    my $conf = $1;
    $conf eq "no debugging" and $conf = "";
    push @conf2, $conf;
    shift @body;
  }
  $result->{conf1} = \@conf1;

  $result->{compiler_msgs} = [];
  $result->{nonfatal_msgs} = [];
  while (@body) {
    my $line = shift @body;
    if ($line =~ /^Compiler messages\(.*\):$/) {
      my @ccmsgs;
      while (@body && $body[0] =~ /\S/) {
	push @ccmsgs, shift @body;
      }
      $result->{compiler_msgs} = \@ccmsgs;
    }
    elsif ($line =~ /^non-fatal messages\(.*\):$/i) {
      my @nfmsgs;
      while (@body && $body[0] =~ /\S/) {
	push @nfmsgs, shift @body;
      }
      $result->{nonfatal_msgs} = \@nfmsgs;
    }
    elsif ($line =~ /^Configuration: (\w+)$/) {
      $result->{configuration} = $1;
    }
    elsif ($line =~ /^Branch: ([\w\/-]+)$/) {
      $result->{branch} = $1;
    }
  }

  fill_correlations($result);


  return 1;
}

sub _escape($s) {
  $s =~ s/([^[:print:]])/ sprintf("\\x{%x}", ord $1) /ger;
}

1;
