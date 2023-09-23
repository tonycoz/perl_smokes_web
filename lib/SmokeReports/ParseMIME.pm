package SmokeReports::ParseMIME;
use strict;
use Exporter qw(import);
use MIME::Parser;
use DateTime::Format::Mail;

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

sub parse_report {
    my ($report_data, $verbose) = @_;

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

sub _process_report {
  my ($result, $report_data) = @_;

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

  chomp @body;
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

  if ($body[0] =~ /^(\s+)?/) {
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
  my $host_line = shift @body;
  my $os_line = shift @body;
  my ($host, $cpu_full) = $host_line =~ /^([a-z.0-9-]+):\s*(.*)/i
    or die "Cannot parse host line: $host_line\n";
  $result->{host} = $host;
  $result->{cpu_full} = $cpu_full;

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
    if (@body && $body[0] =~ /^(.*?) ([a-z]\d\.\d+.*)/i) {
      push @cc, { cc => $1, version => $2, index => 1 };
    }
  }
  unless (@cc) {
    my $line = @body ? $body[0] : "<no line>";
    die "No compiler lines seen\n$line\n";
  }
  $result->{compiler} = "$cc[0]{cc} $cc[0]{version}";

  my ($day, $hour, $minute) = ( 0, 0 );
  if (@body && $body[0] =~ /^\s+smoketime
                            (?:\s+(\d+) days?)?
			    (?:\s+(\d+) hours?)?
			    (?:\s+(\d+) minutes?)?\s*$
			   /x) {
    ($day, $hour, $minute) = ( $1, $2, $3 );
    $day    ||= 0;
    $hour   ||= 0;
    $minute ||= 0;
    shift @body;
  }
  $result->{duration} = $day * 86_400 + $hour * 3600 + $minute * 60;

  if (@body && $body[-1] =~ /^Configuration: (\w+)$/) {
    $result->{configuration} = $1;
  }
  if (@body > 1 && $body[-2] =~ /^Branch: ([\w\/-]+)$/) {
    $result->{branch} = $1;
  }

  return 1;
}

1;
