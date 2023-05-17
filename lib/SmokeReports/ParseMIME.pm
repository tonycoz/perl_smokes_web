package SmokeReports::ParseMIME;
use strict;
use Exporter qw(import);
use MIME::Parser;
use DateTime::Format::Mail;

our $VERSION = "1.000";

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
    my ($report, $verbose) = @_;

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
      _process_report(\%result, $report);
      1;
    } or do {
      print "\nError: $@\n" if $verbose;
      $result{error} = $@;
    };

    \%result;
}

sub _process_report {
  my ($result, $report) = @_;

  my $entity = _parser()->parse_data($report);
  my $head = $entity->head;
  my @body = $entity->bodyhandle->as_lines;
  $result->{body} = join '', @body;
  
  $head->unfold;
  my $subject = $entity->get("Subject");
  chomp $subject;
  $result->{subject} = $subject;
  my $from = $entity ->get("From");
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

  my ($v, $status, $os, $cpu, $cpu_count, $cores, $cfg) =
    $subject =~ /^Smoke \[([0-9.a-zA-Z_\/!\+-]*)\] \S+ (PASS(?:-so-far)?|FAIL\(.+\)) (.*)\s\((.*)\/(?:([0-9]+) cpu(?:\[([0-9]+) cores\])?)?\)(?:\s+\{([^\{\}]+)\})?\s*$/
      or die "Cannot parse subject\n";
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
  while (@body && $body[0] !~ /^Automated smoke report /) {
    shift @body;
  }
  @body
    or die "No report prologue found in body\n";

  # first line should be an intro
  my $first = shift @body;
  my ($sha) = $first =~ /^Automated smoke report for (?:branch [\w\\\/-]+ )?[0-9.]+ patch ([0-9a-f]+)/
    or die "Cannot parse SHA from '$first'\n";
  $result->{sha} = $sha;
  # the os390 reports include a describe line before the host line
  # so skip looking for a host line
  while (@body && $body[0] !~ /^([a-z.0-9-]+):\s*(.*)/i) {
    shift @body;
  }
  my ($host_line, $os_line, $cc_line, $dur_line) = @body;
  my ($host, $cpu_full) = $host_line =~ /^([a-z.0-9-]+):\s*(.*)/i
    or die "Cannot parse host line: $host_line\n";
  $result->{host} = $host;
  $result->{cpu_full} = $cpu_full;

  my ($cc) = $cc_line =~ /^\s+using\s+(.* version.*)$/
    or die "Cannot parse CC line: $cc_line\n";
  $result->{compiler} = $cc;

  my ($hour, $minute) = ( 0, 0 );
  $dur_line =~ /([0-9]+) hour/ and $hour = $1;
  $dur_line =~ /([0-9]+) minute/ and $minute = $1;
  $result->{duration} = $hour * 3600 + $minute * 60;

  if (@body && $body[-1] =~ /^Configuration: (\w+)$/) {
    $result->{configuration} = $1;
  }
  if (@body > 1 && $body[-2] =~ /^Branch: ([\w\/-]+)$/) {
    $result->{branch} = $1;
  }
  $result->{msg_id} = $entity->get('Message-Id')
      or die "No Message-Id header found\n";
  chomp($result->{msg_id});

  # if this comes from a new enough version of Test::Smoke assume the
  # smokedb will return it at some point.  First find the signature,
  # which might not be last
  # LINE: for my $line (reverse @body) {
  #   if ($line =~ /Report by Test::Smoke v([0-9._]+)/) {
  #     my $vers = eval $1;
  #     if ($vers >= 1.49
  # 	  && !($result->{os} eq 'MSWin32' && $result->{from_email} =~ /greer/)
  # 	  && !($result->{os} =~ m(^os/390))) {
  # 	die "This should be in the smoke db, skipping";
  #     }
  #     last LINE;
  #   }
  # }

  return 1;
}


1;
