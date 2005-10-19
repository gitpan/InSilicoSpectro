#!/usr/bin/env perl
use Test::More tests => 2;
use File::Basename;
my $dir=dirname $0;
is( system("$dir/testIO.pl 0 $dir/?.txt >/dev/null"), 0);
is( system("$dir/testIO.pl 1 $dir/a.fasta.gz >/dev/null"), 0);
