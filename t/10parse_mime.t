#!perl
use SmokeReports::Sensible;
use Test::More;
use Cpanel::JSON::XS;
use SmokeReports::ParseMIME;
use Data::Dumper;

{
    my $j = load_json("t/243680.json");
    my $p = SmokeReports::ParseMIME::parse_report($j->{raw_report}, 0);
    ok($p, "got some data");
    is($p->{msg_id}, $j->{msg_id}, "msg_id");
    is($p->{sha}, "d1d17ec1ca01d3c59b76a0bf8f9882b5a4b667f6", "sha");
    is($p->{status}, "PASS", "status");
    is($p->{os}, "Solaris 2.11", "os");
    is($p->{subject}, "Smoke [blead] v5.31.7-11-gd1d17ec1ca PASS Solaris 2.11 (i386/1 cpu)", "subject");
    is($p->{cpu}, "i386", "cpu");
    is($p->{cpu_count}, 1, "cpu_count");
    is($p->{cpu_full}, "i86pc (2067MHz) (i386/1 cpu)", "cpu_full");
    is($p->{host}, "cjg-omniosce", "host");
    is($p->{compiler}, "gcc 7.4.0", "compiler");
    is($p->{configuration}, undef, "configuration");
    is_deeply($p->{conf1_struct},
	      {
	       common => [ "-Dcc=gcc" ],
	       extra => [
			 [ ],
			 [ "-Duse64bitall" ],
			 [ "-Duselongdouble" ],
			 [ "-Duseithreads" ],
			 [ "-Duse64bitall", "-Duseithreads" ],
			 [ "-Duseithreads", "-Duselongdouble" ],
			 ]
	      }, "conf1_struct")
      or do { use Data::Dumper; diag(Dumper($p->{conf1_struct})) };
    is_deeply($p->{test_failures_summary}, [], "no failures");
    is_deeply($p->{todo_passed_summary}, [], "no todo_passed");
}

{
  my $p = parse_mime_file('t/reports/344450.mime');
  ok($p, "parsed 344450");
  is($p->{msg_id}, '<202608202021.67KKL8kT1120135@vier.local>', "msg_id");
  is($p->{sha}, 'fd584474cf36982e2f2ef85b042ea51bb02fffaa', "sha");
  is_deeply($p->{test_failures_summary},
	    [
	     {
	      file => '../lib/locale_threads.t',
	      configs =>
	      [
	       "[default] -DDEBUGGING -Duseithreads"
	      ],
	      messages =>
	      [
	       "2"
	      ],
	      },
	    ],
	    "test_failures");
  is_deeply($p->{todo_passed_summary},
	    [
	     {
	      file => '../ext/IPC-Open3/t/IPC-Open3.t',
	      configs =>
	      [
	       '[default]',
	       '[default] -DDEBUGGING',
	       '[default] -DDEBUGGING -Duseithreads',
	       '[default] -Duseithreads',
	      ],
	      messages =>
	      [
	       '33'
	      ],
	     },
	     {
	      file => '../t/win32/stat.t',
	      configs =>
	      [
	       '[default]',
	       '[default] -DDEBUGGING',
	      ],
	      messages =>
	      [
	       '42'
	      ],
	     },
	    ], "todo_passed")
    or diag Dumper($p->{todo_passed_summary});
}

done_testing();

sub load_json {
    my $fname = shift;
    open my $fh, "<:raw", $fname
	or die "Cannot open $fname: $!\n";
    my $raw = do { local $/; <$fh> };
    close $fh;
    my $json = Cpanel::JSON::XS->new->utf8;
    return $json->decode($raw);
}

sub parse_mime_file($fname) {
  open my $fh, "<:raw", $fname
    or die "Cannot open $fname: $!\n";
  my $raw = do { local $/; <$fh> };
  close $fh;
  
  return SmokeReports::ParseMIME::parse_report($raw, 0);
}
