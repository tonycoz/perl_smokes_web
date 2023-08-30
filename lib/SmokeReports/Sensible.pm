package SmokeReports::Sensible;
use v5.32.0;
use strict;
use warnings;
use experimental;
use builtin;

sub import {
    strict->import;
    warnings->import;
    feature->unimport(":all"); # disable indirect etc
    feature->import(":5.32.0", "fc", "bitwise");
    experimental->import("re_strict", "regex_sets", "signatures", "builtin");
    feature->unimport("switch", "indirect");
    builtin->import(qw(true false trim));
}

1;

=head1 NAME

SmokeReports::Sensible - sensible features/defaults for SmokeReports code.

=head1 SYNOPSIS

  use SmokeReports::Sensible;

=head1 DESCRIPTION

Set reasonable features and compilation defaults for SmokeReports
code, this includes:

  use strict;
  use warnings;
  use feature ':5.32.0', 'fc', 'bitwise';
  use experimental 're_strict', 'regex_sets', 'signatures';
  no feature "switch", "indirect";

=cut
