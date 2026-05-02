#!/usr/bin/perl -w
use strict;
use Net::NNTP;
use Getopt::Long;
use SmokeReports::Config;
use SmokeReports::Dbh;

my $host = "nntp.perl.org";
my $group = "perl.daily-build.reports";

my $verbose;
GetOptions("v:i" => \$verbose,
	   "h=s" => \$host);

if (defined $verbose) {
  $verbose or $verbose = 1;
}
else {
  $verbose = 0;
}

my $schema = SmokeReports::Dbh->schema;
my $dbr = $schema->resultset("DailyBuildReport");

my $nntp_last = $dbr->search(
    { },
    {
	columns => [ "nntp_num" ],
	order_by => "nntp_num desc",
	rows => 1
    });
my ($start_num) = map { $_->nntp_num } $nntp_last->all;
# just in case we were in the middle of a transaction
$start_num -= 5;
if ($start_num < 0) {
    $start_num = 1;
}

my $nntp = Net::NNTP->new($host)
  or die $@;

print "Connected to $host\n" if $verbose;

my ($msg_count, $first, $last) = $nntp->group($group)
  or die;

defined $start_num or $start_num = 69000;

print "Group: count $msg_count first $first last $last\n"
  if $verbose > 1;

$start_num -= 100;

$start_num < $first and $start_num = $first;

my $seen_res = $dbr->search(
    {
	nntp_num => { '>=', $start_num },
    },
    {
	columns => [ qw(msg_id) ],
    });

my %seen;
while (my $row = $seen_res->next) {
    $seen{$row->msg_id} = 1;
}

print "starting $start_num\n" if $verbose > 1;

my $count = 0;
my $msg_id = $nntp->nntpstat($start_num);
do {
  my ($nntp_num) = split ' ', $nntp->message;

  print "Message $nntp_num/$last => $msg_id\n" if $verbose > 2;

  if ($seen{$msg_id}) {
    print "  have this message\n" if $verbose > 3;
  }
  else {
    print "  new message, fetching article\n" if $verbose > 3;
    my $article = $nntp->article
      or die;
    my $text = join("", @$article);

    my %row =
	(
	 raw_report => $text,
	 nntp_num => $nntp_num,
	 msg_id => $msg_id
	);
    $dbr->create(\%row);
    ++$count;
  }
} while ($count < 100
	 && defined($msg_id = $nntp->next));

$nntp->quit;
print "disconnected from $host\n" if $verbose;
