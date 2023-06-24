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

my $dbh = SmokeReports::Dbh->dbh;

$dbh->{RaiseError} = 1;

my ($start_num) = $dbh->selectrow_array(<<SQL);
select max(nntp_num) from daily_build_reports
SQL

my $nntp = Net::NNTP->new($host)
  or die $@;

print "Connected to $host\n" if $verbose;

my ($msg_count, $first, $last) = $nntp->group($group)
  or die;

defined $start_num or $start_num = 69000;

print "Group: count $msg_count first $first last $last\n"
  if $verbose > 1;

$start_num -= 200;

$start_num < $first and $start_num = $first;

my $count = 0;
my $msg_id = $nntp->nntpstat($start_num);
do {
  my ($nntp_num) = split ' ', $nntp->message;

  print "Message $nntp_num => $msg_id\n" if $verbose > 2;
  
  # look for that msg id
  my ($have_it) = $dbh->selectrow_array(<<SQL, {}, $msg_id);
select count(*) from daily_build_reports
where msg_id = ?
SQL

  if ($have_it) {
    print "  have this message\n" if $verbose > 3;
  }
  else {
    print "  new message, fetching article\n" if $verbose > 3;
    my $article = $nntp->article
      or die;
    my $text = join("", @$article);

    $dbh->do(<<SQL, {}, $text, $nntp_num, $msg_id);
insert into daily_build_reports(raw_report, nntp_num, msg_id)
                       values(?,?,?)
SQL
    #print "Added $nntp_num/$msg_id\n";
    #sleep 1;
  }
} while (++$count < 100
	 && defined($msg_id = $nntp->next));

$nntp->quit;
print "disconnected from $host\n" if $host;
