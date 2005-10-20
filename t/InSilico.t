#!/usr/bin/env perl
use Test::More tests => 44;
use File::Basename;
my $dir=dirname($0)."/InSilico";
my $env="INSILICOSPECTRO_DEFFILE=".dirname($0)."/InSilico/insilicodef.xml";

is(system("$env $dir/testSequence.pl 1 > /dev/null"), 0);

is(system("$env $dir/testAASequence.pl 1 > /dev/null"), 0);
is(system("$env $dir/testAASequence.pl 3 > /dev/null"), 0);

is(system("$env $dir/testPeptide.pl 1 > /dev/null"), 0);
is(system("$env $dir/testPeptide.pl 2 > /dev/null"), 0);
is(system("$env $dir/testPeptide.pl 3 > /dev/null"), 0);

is(system("$env $dir/testCleavEnzyme.pl > /dev/null"), 0);

is(system("$env $dir/testModRes.pl 1 > /dev/null"), 0);
is(system("$env $dir/testModRes.pl 2 > /dev/null"), 0);

is(system("$env $dir/testCalcDigest.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcDigest.pl 2 > /dev/null"), 0);
is(system("$env $dir/testCalcDigest.pl 3 > /dev/null"), 0);
is(system("$env $dir/testCalcDigest.pl 4 > /dev/null"), 0);
is(system("$env $dir/testCalcDigest.pl 5 > /dev/null"), 0);

is(system("$env $dir/testCalcDigestOOP.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcDigestOOP.pl 2 > /dev/null"), 0);
is(system("$env $dir/testCalcDigestOOP.pl 3 > /dev/null"), 0);
is(system("$env $dir/testCalcDigestOOP.pl 4 > /dev/null"), 0);

is(system("$env $dir/testCalcFrag.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcFrag.pl 2 > /dev/null"), 0);

is(system("$env $dir/testCalcFragOOP.pl > /dev/null"), 0);

is(system("$env $dir/testCalcMatch.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcMatch.pl 2 > /dev/null"), 0);
is(system("$env $dir/testCalcMatch.pl 3 > /dev/null"), 0);

is(system("$env $dir/testCalcMatchOOP.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcMatchOOP.pl 2 > /dev/null"), 0);
is(system("$env $dir/testCalcMatchOOP.pl 3 > /dev/null"), 0);

is(system("$env $dir/testCalcPMFMatch.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcPMFMatch.pl 2 > /dev/null"), 0);
is(system("$env $dir/testCalcPMFMatch.pl 3 > /dev/null"), 0);

is(system("$env $dir/testCalcPMFMatchOOP.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcPMFMatchOOP.pl 2 > /dev/null"), 0);

is(system("$env $dir/testCalcVarpept.pl 1 > /dev/null"), 0);
is(system("$env $dir/testCalcVarpept.pl 2 > /dev/null"), 0);
is(system("$env $dir/testCalcVarpept.pl 3 > /dev/null"), 0);
is(system("$env $dir/testCalcVarpept.pl 4 > /dev/null"), 0);

is(system("$env $dir/testMSMSOutText.pl 1 > /dev/null"), 0);
is(system("$env $dir/testMSMSOutText.pl 2 > /dev/null"), 0);
is(system("$env $dir/testMSMSOutHtml.pl > /dev/null"), 0);
is(system("$env $dir/testMSMSOutLatex.pl > /dev/null"), 0);
is(system("$env $dir/testMSMSOutPlot.pl > /dev/null"), 0);
is(system("$env $dir/testMSMSOutLegend.pl > /dev/null"), 0);

eval{
  require Bio::Perl;
  is(system("$env $dir/testSequence.pl 2 > /dev/null"), 0);
  is(system("$env $dir/testAASequence.pl 2 > /dev/null"), 0);
};
if($@){
 SKIP:{
    skip "no Bio::Perl installed", 2;
  }
}
