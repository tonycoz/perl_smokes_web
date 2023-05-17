#!perl -w
use SmokeReports::Sensible;
use Test::More;

my @warn;
local $SIG{__WARN__} = sub { push @warn, @_ };
ok(!eval '$x = 1', "strict");
sub TestClass::new { bless {}, shift; }
ok(!eval 'new TestClass; 1', "no indirect");

done_testing();