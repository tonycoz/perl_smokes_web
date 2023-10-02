package SmokeReports::ParseUtil;
use strict;
use Exporter qw(import);
use SmokeReports::Sensible;
use Text::ParseWords 'quotewords';

our @EXPORT_OK = qw(canonify_config_opts);

sub canonify_config_opts ($opts) {
  # can't use shellwords() since we want to keep the quotes
  $opts =~ s/^\s+//;
  $opts =~ s/\s+$//;
  return join ' ', sort { $a cmp $b }
    quotewords(qr/\s+/, 1, $opts);
}

1;
