#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile
  (
   VERSION   => '0.01',
   PREREQ_PM =>
   {
    'DBIx::Class' => '0.082841',
    'MIME::Parser' => 0,
    'DateTime::Format::Mail' => 0,
    'Cpanel::JSON::XS' => 0,
    perl => v5.32,
   },
   test => {TESTS => 't/*.t'},
);
