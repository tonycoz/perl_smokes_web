package Smokes::Helpers::Config;
use Smokes::Helpers::Sensible;
use FindBin;
use Path::Tiny;
use Cpanel::JSON::XS;

my $config;

sub config {
    unless ($config) {
	my $path = Path::Tiny->new($FindBin::Bin);
	while (!$path->child("smoke.cfg")->is_file) {
	    $path = $path->parent;
	    $path->is_rootdir and die "Could not find smoke.cfg";
	}

	$config = Cpanel::JSON::XS->new->utf8
	    ->decode($path->child("smoke.cfg")->slurp);
    }
    $config;
}

1;
