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
my $nothing;
GetOptions("v:i" => \$verbose,
	   "u=s" => \$base_url,
	   "a" => \$all,
	   "n" => \$nothing,
           "i=i" => \@ids);

if (defined $verbose) {
  $verbose or $verbose = 1;
}
else {
  $verbose = 0;
}

my $config = SmokeReports::Config->config;

unless ($base_url) {
  $base_url = $config->{basenntp_url}
    or die "basenntp_url not defined";
}

$base_url =~ m(/$)
  or die "$base_url needs a final /";

my $logpath = $config->{logpath}
  or die "logpath not defined";

-d $logpath
  or die "logpath '$logpath' not a directory";

my $data_url = "${base_url}api/nntp_data/";
my $reports_from_url = "${base_url}api/nntp_from_id/";

my $schema = SmokeReports::Dbh->schema;
my $dbr = $schema->resultset("DailyBuildReport");

my $start_id;
if ($all) {
  $start_id = 1;
}
else {
    my $nntp_last = $dbr->search(
	{ },
	{
	    columns => [ "nntp_num" ],
	    order_by => "nntp_num desc",
	    rows => 1
	});
    ($start_id) = map { $_->nntp_num } $nntp_last->all;
    # just in case we were in the middle of a transaction
    $start_id -= 5;
    if ($start_id < 0) {
	$start_id = 1;
    }
}
print "Start id $start_id\n" if $verbose;
my %seen_ids;
my $id_q = $dbr->search({}, { columns => [ qw(id nntp_num) ] });
while (my $row = $id_q->next) {
  $seen_ids{$row->nntp_num} = $row->id;
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

    my $data = $result->content;

    $seen_ids{$id} = undef;

    # this doesn't need to be especially error recoverable
    # since it's intended for populating a dev database from the
    # live data, so just die when things are wrong.
    my ($headers, $body) = split /\r?\n\r?\n/, $data;
    $body or die "Invalid response data\n";
    my @headers = split /\r?\n/, $headers;
    my ($msg_id_hdr) = grep /^message-id:\s+/iaa, @headers
	or die "Missing message-id header in\n$headers";
    my ($msg_id) = $msg_id_hdr =~ /^message-id:\s+(<[^>]+>)/iaa
	or die "No message id fount in\n$msg_id_hdr";

    my %row =
	(
	 nntp_num => $id,
	 raw_report => $data,
	 msg_id => $msg_id
	);

    unless ($nothing) {
	my $row = $dbr->create(\%row);
    }

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

