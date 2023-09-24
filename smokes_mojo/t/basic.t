use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('SmokesMojo');
$t->get_ok('/')->status_is(200)->content_like(qr/Reports for branch blead/i);

done_testing();
