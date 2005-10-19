#!/usr/bin/env perl
BEGIN{
  use File::Basename;
  push @INC, (dirname $0).'/../../lib';
}

END{
}


use Test::More tests => 3;
use File::Basename;
my $dir=dirname $0;

use InSilicoSpectro::Spectra::MSSpectra;
is(InSilicoSpectro::Spectra::MSSpectra::string2chargemask('2+ AND 3+'), 12);
is( system("$dir/testPeakDescriptor.pl"), 0);
is( system("$dir/testSpectra.pl 1 $dir/166.dta dta"), 0);
