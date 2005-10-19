#!/usr/bin/env perl
use Test::More tests => 44;
use File::Basename;
my $dir=dirname $0;

is(system("$dir/testSequence.pl 1 > /dev/null"), 0);

is(system("$dir/testAASequence.pl 1 > /dev/null"), 0);
is(system("$dir/testAASequence.pl 3 > /dev/null"), 0);

is(system("$dir/testPeptide.pl 1 > /dev/null"), 0);
is(system("$dir/testPeptide.pl 2 > /dev/null"), 0);
is(system("$dir/testPeptide.pl 3 > /dev/null"), 0);

is(system("$dir/testCleavEnzyme.pl > /dev/null"), 0);

is(system("$dir/testModRes.pl 1 > /dev/null"), 0);
is(system("$dir/testModRes.pl 2 > /dev/null"), 0);

is(system("$dir/testCalcDigest.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcDigest.pl 2 > /dev/null"), 0);
is(system("$dir/testCalcDigest.pl 3 > /dev/null"), 0);
is(system("$dir/testCalcDigest.pl 4 > /dev/null"), 0);
is(system("$dir/testCalcDigest.pl 5 > /dev/null"), 0);

is(system("$dir/testCalcDigestOOP.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcDigestOOP.pl 2 > /dev/null"), 0);
is(system("$dir/testCalcDigestOOP.pl 3 > /dev/null"), 0);
is(system("$dir/testCalcDigestOOP.pl 4 > /dev/null"), 0);

is(system("$dir/testCalcFrag.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcFrag.pl 2 > /dev/null"), 0);

is(system("$dir/testCalcFragOOP.pl > /dev/null"), 0);

is(system("$dir/testCalcMatch.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcMatch.pl 2 > /dev/null"), 0);
is(system("$dir/testCalcMatch.pl 3 > /dev/null"), 0);

is(system("$dir/testCalcMatchOOP.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcMatchOOP.pl 2 > /dev/null"), 0);
is(system("$dir/testCalcMatchOOP.pl 3 > /dev/null"), 0);

is(system("$dir/testCalcPMFMatch.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcPMFMatch.pl 2 > /dev/null"), 0);
is(system("$dir/testCalcPMFMatch.pl 3 > /dev/null"), 0);

is(system("$dir/testCalcPMFMatchOOP.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcPMFMatchOOP.pl 2 > /dev/null"), 0);

is(system("$dir/testCalcVarpept.pl 1 > /dev/null"), 0);
is(system("$dir/testCalcVarpept.pl 2 > /dev/null"), 0);
is(system("$dir/testCalcVarpept.pl 3 > /dev/null"), 0);
is(system("$dir/testCalcVarpept.pl 4 > /dev/null"), 0);

is(system("$dir/testMSMSOutText.pl 1 > /dev/null"), 0);
is(system("$dir/testMSMSOutText.pl 2 > /dev/null"), 0);
is(system("$dir/testMSMSOutHtml.pl > /dev/null"), 0);
is(system("$dir/testMSMSOutLatex.pl > /dev/null"), 0);
is(system("$dir/testMSMSOutPlot.pl > /dev/null"), 0);
is(system("$dir/testMSMSOutLegend.pl > /dev/null"), 0);

eval{
  require Bio::Perl;
  is(system("$dir/testSequence.pl 2 > /dev/null"), 0);
  is(system("$dir/testAASequence.pl 2 > /dev/null"), 0);
};
if($@){
 SKIP:{
    skip "no Bio::Perl installed", 2;
  }
}
