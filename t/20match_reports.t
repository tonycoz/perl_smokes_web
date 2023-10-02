#!perl
use SmokeReports::Sensible;
use Test::More;
use SmokeReports::Dbh;
use SmokeReports::ParseMIME qw(parse_report);
use SmokeReports::ParseSmokeDB qw(parse_smoke_report);

my $schema = SmokeReports::Dbh->schema;
my $dbr = $schema->resultset("DailyBuildReport");
my $p5s = $schema->resultset("Perl5Smoke");

ok($dbr, "get DailyBuildReports");
ok($p5s, "get Perl5Smoke");

{
    my @build_match =
	( # nntpid smokeid name
	  [ 297009, 5040197, "simple arch linux" ],
	  [ 296949, 5040119, "failing on fedora" ],
	  [ 296943, 5040111, "ubuntu success" ],
	  [ 296937, 5040100, "fedora success sanitize" ],
	  [ 296941, 5040107, "fedora success quick" ],
	);

    for my $match (@build_match) {
	my ($nntp_id, $report_id, $name) = @$match;

	my $nntp = $dbr->find({ nntp_num => $nntp_id});
	my $smoke = $p5s->find({ report_id => $report_id });
	ok($nntp, "$name: got nntp $nntp_id");
	ok($smoke, "$name: got smoke $report_id");
	my $nntp_parsed = parse_report($nntp->raw_report, 0);
	my $smoke_parsed = parse_smoke_report($smoke->raw_report, 0);
	is($nntp_parsed->{error}, "", "$name: no error parsing nntp");
	is($smoke_parsed->{error}, "", "$name: no error parsing smoke");
	is($nntp_parsed->{by_config_full}, $smoke_parsed->{by_config_full},
	   "$name: configs match")
	    or diag_compare($nntp_parsed->{by_config_full},
			    $smoke_parsed->{by_config_full});
	is($nntp_parsed->{by_build_full}, $smoke_parsed->{by_build_full},
	   "$name: builds match");
	is($nntp_parsed->{config_hash}, $smoke_parsed->{config_hash},
	   "$name: config hashes match");
	is($nntp_parsed->{build_hash}, $smoke_parsed->{build_hash},
	   "$name: build hashes match");
    }
}
{
    
    my @build_nomatch =
	( # nntpid smokeid name
	  [ 296975, 5040249, "simple arch linux" ],
	  [ 296949, 5040181, "failing on fedora" ],
	  [ 296943, 5040157, "ubuntu success" ],
	  [ 296937, 5040125, "fedora success sanitize" ],
	  [ 296941, 5040126, "fedora success quick" ],
	);
    # config should match but not build
    for my $match (@build_nomatch) {
	my ($nntp_id, $report_id, $name) = @$match;

	my $nntp = $dbr->find({ nntp_num => $nntp_id});
	my $smoke = $p5s->find({ report_id => $report_id });
	ok($nntp, "$name: got nntp $nntp_id");
	ok($smoke, "$name: got smoke $report_id");
	my $nntp_parsed = parse_report($nntp->raw_report, 0);
	my $smoke_parsed = parse_smoke_report($smoke->raw_report, 0);
	is($nntp_parsed->{error}, "", "$name: no error parsing nntp");
	is($smoke_parsed->{error}, "", "$name: no error parsing smoke");
	is($nntp_parsed->{by_config_full}, $smoke_parsed->{by_config_full},
	   "$name: configs match")
	    or diag_compare($nntp_parsed->{by_config_full},
			    $smoke_parsed->{by_config_full});
	isnt($nntp_parsed->{by_build_full}, $smoke_parsed->{by_build_full},
	   "$name: builds don't match");
	is($nntp_parsed->{config_hash}, $smoke_parsed->{config_hash},
	   "$name: config hashes match");
	isnt($nntp_parsed->{build_hash}, $smoke_parsed->{build_hash},
	     "$name: build hashes don't match");
    }
}
done_testing();

sub diag_compare ($left, $right) {
    my $left_len = length $left;
    my $right_len = length $right;
    my $len = $left_len < $right_len ? $left_len : $right_len;
    while ($len && substr($left, 0, $len) ne substr($right, 0, $len)) {
	--$len;
    }
    my $left_tail = substr($left, $len, 10);
    my $right_tail = substr($right, $len, 10);
    diag "first mismatch at character $len:";
    diag "Left : $left_tail";
    diag "Right: $right_tail";
    diag "Left hex : ".unpack("H*", $left_tail);
    diag "Right hex: ".unpack("H*", $right_tail);
}
