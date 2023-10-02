package SmokeReports::ParseUtil;
use strict;
use Exporter qw(import);
use SmokeReports::Sensible;
use Text::ParseWords 'quotewords';
use Digest::SHA qw(sha256_base64);

our @EXPORT_OK = qw(canonify_config_opts fill_correlations);

sub canonify_config_opts ($opts) {
  # can't use shellwords() since we want to keep the quotes
  $opts =~ s/^\s+//;
  $opts =~ s/\s+$//;
  return join ' ', sort { $a cmp $b }
    quotewords(qr/\s+/, 1, $opts);
}

sub fill_correlations ($result) {
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
}

1;
