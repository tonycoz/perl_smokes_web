package Smokes::Helpers::Dbh;
use Smokes::Helpers::Sensible;
use Smokes::Helpers::Config;
use strict;
use DBI;

{
    my $dbh;

    sub dbh {
	if ($dbh && !$dbh->ping) {
	    undef $dbh;
	}
	unless ($dbh) {
	    my $config = Smokes::Helpers::Config->config;
	    my $dbconfig = $config->{db}
	      or die "Missing db config";
	    my $dsn = $dbconfig->{dsn}
	      or die "Missing dsn from db config";
	    my $user = $dbconfig->{user}
	      or die "Missing user from db config";
	    my $password = $dbconfig->{password}
	      or die "Missing password from db config";
	    my $attr = $dbconfig->{attr}
	      or die "Missing attr from db config";
	    $dbh = DBI->connect($dsn, $user, $password, $attr)
		or die $DBI::errstr;
	}

	$dbh;
    }
}

sub schema {
  state $schema;
  unless ($schema) {
    require Smokes::Schema;

    my $config = Smokes::Helpers::Config->config;
    my $dbconfig = $config->{db}
      or die "Missing db config";
    my $dsn = $dbconfig->{dsn}
      or die "Missing dsn from db config";
    my $user = $dbconfig->{user}
      or die "Missing user from db config";
    my $password = $dbconfig->{password}
      or die "Missing password from db config";
    my $attr = $dbconfig->{attr}
      or die "Missing attr from db config";
    $schema = Smokes::Schema->connect($dsn, $user, $password, $attr)
  }

  $schema;
}

1;
