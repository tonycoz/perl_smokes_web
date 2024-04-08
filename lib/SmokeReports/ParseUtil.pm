package SmokeReports::ParseUtil;
use strict;
use Exporter qw(import);
use SmokeReports::Sensible;
use Text::ParseWords 'quotewords';
use Digest::SHA qw(sha256_base64);

our @EXPORT_OK = qw(canonify_config_opts fill_common);

sub canonify_config_opts ($opts) {
  # can't use shellwords() since we want to keep the quotes
  $opts =~ s/^\s+//;
  $opts =~ s/\s+$//;
  return join ' ', sort { $a cmp $b }
    quotewords(qr/\s+/, 1, $opts);
}

sub fill_common ($result) {
  my $conf1 = join "", map("$_\n", $result->{conf1}->@*);

  my $conf_os = $result->{os};
  # I want the os match to be a little loose
  # linux dists have lots of little patches, but we want
  # then to stay matched
  if ($conf_os =~ /^linux /) {
    $conf_os =~ s/(linux \d+\.\d+)\.\d+(?:-\d+)?/$1.xx/;
  }
  $result->{by_config_full} = join "",
    "$result->{host}\n$conf_os\n$conf1";

  # the build os stays strict
  my $dur_m = int($result->{duration} / 60) * 60;
  $result->{by_build_full} = <<EOS;
$result->{host}
$result->{os}
$conf1--
$dur_m
EOS
  $result->{config_hash} = sha256_base64($result->{by_config_full});
  $result->{build_hash} = sha256_base64($result->{by_build_full});

  # configs
  my %conf_counts;
  for my $conf ($result->{conf1}->@*) {
    # make sure we ignore duplicates
    my %seen = map { $_ => 1 } quotewords(qr/\s+/, 1, $conf);
    ++$conf_counts{$_} for keys %seen;
  }

  my @common = grep {; $conf_counts{$_} == $result->{conf1}->@* }
    keys %conf_counts;
  my %common = map { $_ => 1 } @common;
  my @myconf1;
  for my $conf ($result->{conf1}->@*) {
    my @row = grep !$common{$_}, quotewords(qr/\s+/, 1, $conf);
    push @myconf1, \@row;
  }
  my %conf1 =
    (
     common => \@common,
     extra => \@myconf1,
     );
  $result->{conf1_struct} = \%conf1;
}

1;
