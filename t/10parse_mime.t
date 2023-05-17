#!perl
use strict;
use warnings;
use Test::More;
use JSON;
use SmokeReports::ParseMIME;

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
    is($p->{compiler}, "gcc version 7.4.0", "compiler");
    is($p->{configuration}, undef, "configuration");
}

done_testing();

sub load_json {
    my $fname = shift;
    open my $fh, "<:raw", $fname
	or die "Cannot open $fname: $!\n";
    my $raw = do { local $/; <$fh> };
    close $fh;
    my $json = JSON->new->utf8;
    return $json->decode($raw);
}
