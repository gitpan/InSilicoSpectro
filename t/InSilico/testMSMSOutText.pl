#!/usr/bin/perl

# Test program for Perl module MSMSOutput.pm
# Copyright (C) 2005 Jacques Colinge

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Contact:
#  Prof. Jacques Colinge
#  Upper Austria University of Applied Science at Hagenberg
#  Hauptstrasse 117
#  A-4232 Hagenberg, Austria
#  http://www.fhs-hagenberg.ac.at


BEGIN{
  use File::Basename;
  push @INC, (dirname $0).'/../../lib';
}

use strict;
use Carp;
use InSilicoSpectro;
use InSilicoSpectro::InSilico::MassCalculator;
use InSilicoSpectro::InSilico::Peptide;
use InSilicoSpectro::Spectra::PeakDescriptor;
use InSilicoSpectro::Spectra::ExpSpectrum;
use InSilicoSpectro::InSilico::MSMSTheoSpectrum;
use InSilicoSpectro::InSilico::MSMSOutput;

eval{
  InSilicoSpectro::init();
  my $test = shift;

  if ($test == 1){
    # Test 1, no object except MSMSOutput that must be an object always
    my %spectrum;
    my $peptide = 'SCMSFPQMLS';
    my $modif = '::Cys_CAM::::::Oxidation:::';
    getFragmentMasses(pept=>$peptide, modif=>$modif, fragTypes=>['b','a','b-NH3*','b-H2O*','b++','y','y-H2O*-NH3*','y++','immo'], spectrum=>\%spectrum);
    my @expSpectrum = ([120,340],[221,100], [494, 250], [820.4, 300], [821, 200], [985,700], [1116, 200]);
    matchSpectrumGreedy(spectrum=>\%spectrum, expSpectrum=>\@expSpectrum, minTol=>2);
    my $msms = new InSilicoSpectro::InSilico::MSMSOutput(spectrum=>\%spectrum, prec=>2, modifLvl=>1, expSpectrum=>\@expSpectrum);
    print $msms->tabSepSpectrum();
  }

  if ($test == 2){
    # Test 2, all objects
    my %spectrum;
    my $peptide = new InSilicoSpectro::InSilico::Peptide(sequence=>'SCMSFPQMLS', modif=>'::Cys_CAM::::::Oxidation:::');
    getFragmentMasses(pept=>$peptide, fragTypes=>['b','a','b-NH3*','b-H2O*','b++','y','y-NH3*','y-H2O*','y++','immo'], spectrum=>\%spectrum);
    my @expSpectrum = ([120,340],[221,100], [494, 250], [820.4, 300], [821, 200], [985,700], [1116, 200]);
    my $pd = new InSilicoSpectro::Spectra::PeakDescriptor(['mass', 'intensity']);
    my $expSpectrum = new InSilicoSpectro::Spectra::ExpSpectrum(spectrum=>\@expSpectrum, peakDescriptor=>$pd);
    matchSpectrumGreedy(spectrum=>\%spectrum, expSpectrum=>$expSpectrum, minTol=>2);
    my $theoSpectrum = new InSilicoSpectro::InSilico::MSMSTheoSpectrum(theoSpectrum=>\%spectrum, massType=>getMassType());
    my $msms = new InSilicoSpectro::InSilico::MSMSOutput(spectrum=>$theoSpectrum, prec=>2, modifLvl=>1, expSpectrum=>$expSpectrum);
    print $msms->tabSepSpectrum();
  }
};
if ($@){
  carp($@);
}
