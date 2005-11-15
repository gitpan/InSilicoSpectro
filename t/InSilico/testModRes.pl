#!/usr/bin/env perl
use strict;

use Carp;

BEGIN{
  use File::Basename;
  push @INC, (dirname $0).'/../../lib';
}

END{
}

use InSilicoSpectro::InSilico::ModRes;
use InSilicoSpectro;
eval{
  InSilicoSpectro::init();
  my $test = shift;

  if ($test == 1){
    print "******* list of all modif *********\n";
    foreach (InSilicoSpectro::InSilico::ModRes::getList()){
      $_->print();
      print "=> ".$_->get('sprotFT')."\n";
    }
  }

  if ($test == 2){
    print "******* given a FT, return the modif name *********\n";
    foreach ('PHOSPHORYLATION', 'N-acetylalanine', 'Phosphoserine (by PKC)]', 'ACETYLATION', 'SULFATION'){
      my $m=InSilicoSpectro::InSilico::ModRes::getModifFromSprotFT($_);
      print "$_ => ".((defined $m)?($m->get('name')):'unknown')."\n";
    }
  }
};

if ($@){
  print STDERR "error trapped in main\n";
  carp $@;
}
