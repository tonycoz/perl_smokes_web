#!/usr/bin/perl -w
use strict;
use LWP::UserAgent;
use Cpanel::JSON::XS;
use Getopt::Long;
use IO::Compress::Gzip qw(gzip);
use SmokeReports::Config;
use SmokeReports::Dbh;

my $base_url;

my $verbose;
my $all;
my @ids;
GetOptions("v:i" => \$verbose,
	   "u=s" => \$base_url,
	   "a" => \$all,
           "i=i" => \@ids);

if (defined $verbose) {
  $verbose or $verbose = 1;
}
else {
  $verbose = 0;
}

my $config = SmokeReports::Config->config;

unless ($base_url) {
  $base_url = $config->{coresmokedb_url}
    or die "coresmokedb_url not defined";
}

$base_url =~ m(/$)
  or die "$base_url needs a final /";

my $logpath = $config->{logpath}
  or die "logpath not defined";

-d $logpath
  or die "logpath '$logpath' not a directory";

my $data_url = "${base_url}report_data/";
my $reports_from_url = "${base_url}reports_from_id/";

my $dbh = SmokeReports::Dbh->dbh;

$dbh->{RaiseError} = 1;

my $start_id;
if ($all) {
  $start_id = 1;
}
else {
  ($start_id) = $dbh->selectrow_array(<<SQL);
select max(report_id) from perl5_smokedb
SQL
  # just in case we were in the middle of a transaction
  $start_id -= 5;
  if ($start_id < 0) {
    $start_id = 1;
  }
}
print "Start id $start_id\n" if $verbose;

my %seen_ids;
my $sth = $dbh->prepare(<<SQL)
select report_id from perl5_smokedb
where report_id >= ?
SQL
  or die "Cannot prepare ids sql: ", $dbh->errstr;
$sth->execute($start_id)
  or die "Cannot execute ids sql: ", $dbh->errstr;
while (my ($row) = $sth->fetchrow_array) {
  $seen_ids{$row} = undef;
}

print "Loaded seen_ids\n" if $verbose;

my $ua = LWP::UserAgent->new;

my $id_json = Cpanel::JSON::XS->new->utf8;
my $json = Cpanel::JSON::XS->new;

my $ids = @ids ? \@ids : fetch_ids($start_id);

while ($ids && @$ids) {
  $ids = [ sort { $a <=> $b } @$ids ];
  for my $id (@$ids) {
    $id =~ /\A-?[1-9][0-9]*\z/
      or die "Unexpected id '$id'";
    # see if we already have it
    if (exists $seen_ids{$id}) {
      $verbose > 5 
	and print STDERR "Already have $id, skipping\n";
      next;
    }

    my $url = "${data_url}$id";
    print "Fetching $url\n" if $verbose >= 10;
    my $result = $ua->get($url);
    $result->is_success
	or die "Cannot fetch report from $url: ", $result->status_line, "\n", $result->decoded_content;

    my $json_data = $result->content;
    my $data = $json->decode($json_data);
    if (my $logdata = $data->{log_file}) {
      $data->{log_file} = "log file removed";
      utf8::encode(my $encdata = $logdata);
      my $cdata = '';
      gzip(\$encdata, \$cdata, -Level => 9);
      open my $lfh, ">", "$logpath/$id.gz"
	or warn "Could not create $id.gz: $!";
      print $lfh $cdata;
      close $lfh
	or warn "Could not close $id.gz: $!";
    }
    $json_data = $json->encode($data);

    $seen_ids{$id} = undef;

    $dbh->do(<<SQL, undef, $json_data, $id, time())
insert into perl5_smokedb(raw_report, report_id, fetched_at)
  values(?,?,?)
SQL
      or die "Cannot store report: ",$dbh->errstr;

    $verbose
      and print STDERR "Fetched $id\n";
  }

  $ids = @ids ? undef : fetch_ids(1+$ids->[-1]);
}

sub fetch_ids {
  my ($baseid) = @_;
  
  my $url = "${reports_from_url}$baseid";
  my $result = $ua->get($url);
  $result->is_success
    or die "Cannot fetch index ($url): ", $result->status_line;

  my $ids = $id_json->decode($result->content);

  $verbose
    and print STDERR "Fetched ", scalar(@$ids), " new ids starting from $baseid\n";

  return $ids;
}

