#!perl
use v5.36;
use Test::More;
use Cpanel::JSON::XS;
use SmokeReports::ParseSmokeDB qw(parse_smoke_report);
use Data::Dumper;

test_parse("t/reports/db5533028.json",
	   sub ($report) {
	     is($report->{cpu}, "arm64", "arch");
	     is_deeply($report->{test_failures},
		       [
			{
			 test => "../dist/Devel-SelfStubber/t/Devel-SelfStubber.t",
			 status => "FAILED",
			 extra => "Non-zero exit status: 22\nBad plan.  You planned 12 tests but ran 4.",
			 configs =>
			 [
			  {
			   io_envs => "stdio",
			   arguments => "",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "DEBUGGING",
			   locale => undef,
			  },
			 ],
			},
			{
			 test => "../dist/SelfLoader/t/01SelfLoader.t",
			 status => "FAILED",
			 extra => "Non-zero exit status: 22\nBad plan.  You planned 20 tests but ran 0.",
			 configs =>
			 [
			  {
			   io_envs => "stdio",
			   arguments => "",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "DEBUGGING",
			   locale => undef,
			  },
			 ],
			},
			{
			 test => "../dist/SelfLoader/t/02SelfLoader-buggy.t",
			 status => "FAILED",
			 extra => "1",
			 configs =>
			 [
			  {
			   io_envs => "stdio",
			   arguments => "",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "DEBUGGING",
			   locale => undef,
			  },
			 ],
			},
		       ], "test_failures");
	     note(Dumper($report->{test_failures}));
	     is_deeply($report->{test_todo_passed}, [],
		       "empty todo passed");
	   }, "failure handling check");

test_parse("t/reports/db5533079.json",
	   sub ($report) {
	     is_deeply($report->{test_failures}, [],
		       "empty test_failures");
	     note(Dumper($report->{test_todo_passed}));
	     is_deeply($report->{test_todo_passed},
		       [
			{
			 test => "../t/run/todo.t",
			 status => "PASSED",
			 extra => "20",
			 configs =>
			 [
			  {
			   io_envs => "stdio",
			   arguments => "-Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duse64bitint DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Uuseperlio DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "DEBUGGING",
			   locale => undef,
			  },
			 ],
			},
			{
			 test => "../t/run/todo.t",
			 status => "PASSED",
			 extra => "6",
			 configs =>
			 [
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duselongdouble",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Duselongdouble DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Dusemorebits",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duseithreads -Dusemorebits DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duselongdouble",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Duselongdouble DEBUGGING",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Dusemorebits",
			   locale => undef,
			  },
			  {
			   io_envs => "stdio",
			   arguments => "-Dusemorebits DEBUGGING",
			   locale => undef,
			  },
			 ],
			},
		       ], "todo_passed");
	   }, "report with todo passed");

test_parse
  ("t/reports/db5537632.json",
   sub ($report) {
     is($report->{sha}, 'fd584474cf36982e2f2ef85b042ea51bb02fffaa', "sha");
     is_deeply($report->{test_failures_summary},
	       [
	     {
	      file => '../lib/locale_threads.t',
	      configs =>
	      [
	       "[stdio] -DDEBUGGING -Duseithreads"
	      ],
	      messages =>
	      [
	       "2"
	      ],
	      },
	    ],
	    "test_failures");
  is_deeply($report->{todo_passed_summary},
	    [
	     {
	      file => '../ext/IPC-Open3/t/IPC-Open3.t',
	      configs =>
	      [
	       '[stdio]',
	       '[stdio] -DDEBUGGING',
	       '[stdio] -DDEBUGGING -Duseithreads',
	       '[stdio] -Duseithreads',
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
	       '[stdio]',
	       '[stdio] -DDEBUGGING',
	      ],
	      messages =>
	      [
	       '42'
	      ],
	     },
	    ], "todo_passed")
    or diag Dumper($report->{todo_passed_summary});
   }, "test fail/todo summaries");

done_testing;

sub test_parse ($filename, $sub, $name) {
  open my $fh, "<:raw", $filename
    or die "Cannot open $filename: $!";
  my $raw = do { local $/; <$fh> };
  close $fh;

  my $result = parse_smoke_report($raw, 0);
  ok($result, "$name: parsed");
  if ($sub) {
    $sub->($result);
  }
}
