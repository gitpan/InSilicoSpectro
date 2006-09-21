#!/usr/bin/env perl
use strict;
use Carp;
use Pod::Usage;

=head1 NAME

convertSpectra.pl


=head1 DESCRIPTION

Converts ms and msms peaklist from/to various formats. Formats can be specified or will hopefully be deduced from the files extensions

=head1 SYNOPSIS

convertSpectra.pl --in=[format:]file --out=[format:]file

=head1 ARGUMENTS

=over 4

=item -in=[format:]file

If the format is not idj, this parameter can be repeated

=item -out=[format:]file

=back

If no files are specified (thus the format must be) I/O are stdin/out.

=head1 OPTIONS

=over 4

=item --defaultcharge=charge

Defined a default charge for the precursor (msms) of the peak (ms) (it might be overwritten if the input file definesit explicitely. The charge argument can be something like '1+', '1', '2,3', '2+ AND 3+' etc.

=item --title=string

Allows for setting a title (one line text)

=item --filter=file

Allows for using a filter. See 'InSilicoSpectro/t/Spectra/Filter/examples.xml' for more information.

=item --sampleinfo='name1=val1[;name2=val2[...]]'

Set sample related info example 'instrument=QTOF;instrumentId=xyz'

=item --trustprecursorcharge=medium

turn 2+ and 3+ precursor  into (2+ OR 3+)

=item --duplicateprecursormoz=i1:i2

If for example i1=-1 and i2=2, precursor moz will be replicate with -1, +1 and +2 Dalton

=item --skip=[msms|pmf]

Do not read msms or pmf information

=item --showinputformats

Prints all the possible format for input

=item --showoutputformats

Prints all the possible format for output

=item --version

=item --help

=item --man

=item --verbose

=back


=head1 EXAMPLE

./convertSpectra.pl --in=dta:somedir --out=somefile.idj.xml

=head1 COPYRIGHT

Copyright (C) 2004-2005  Geneva Bioinformatics www.genebio.com

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=head1 AUTHORS

Alexandre Masselot, www.genebio.com

=cut

use Getopt::Long;
use File::Basename;
my(@fileIn, $fileOut, $showInputFmt, $showOutputFmt, $sampleInfo, $precursorTrustParentCharge, $defaultCharge, $title, $fileFilter, $dpmStr, @skip, $phenyxConfig, $help, $man, $verbose, $showVersion);

use InSilicoSpectro;
if (!GetOptions(
		"in=s@"=>\@fileIn,
		"out=s"=>\$fileOut,
		"sampleinfo=s"=>\$sampleInfo,
		"showinputformats"=>\$showInputFmt,
		"showoutputformats"=>\$showOutputFmt,

		"duplicateprecursormoz=s"=>\$dpmStr,
		"trustprecursorcharge=s"=>\$precursorTrustParentCharge,
		"defaultcharge=s"=>\$defaultCharge,
		"title=s"=>\$title,

		"filter=s"=>\$fileFilter,

		"skip=s@"=>\@skip,
		"phenyxconfig=s" => \$phenyxConfig,


                "version" => \$showVersion,
                "help" => \$help,
                "man" => \$man,
                "verbose" => \$verbose,
               )
    || $help || $man || $showVersion || (((not @fileIn) || (not $fileOut)) and  (not $showInputFmt) and (not $showOutputFmt))){

  if($showVersion){
    print basename($0)." InSilicoSpectro version $InSilicoSpectro::VERSION\n";
    exit(0);
  }

  pod2usage(-verbose=>2, -exitval=>2) if(defined $man);
  pod2usage(-verbose=>1, -exitval=>2);
}

my %sampleInfo;
foreach(split /;/, $sampleInfo){
  my($n, $v)=split /=/, $_, 2;
  $sampleInfo{$n}=$v;
}

die "invalid --trustprecursorcharge=(medium)" if $precursorTrustParentCharge and $precursorTrustParentCharge !~ /^(medium)$/;

use InSilicoSpectro::Spectra::MSRun;
use InSilicoSpectro::Spectra::MSSpectra;
use InSilicoSpectro::Spectra::Filter::MSFilterCollection;

$InSilicoSpectro::Utils::io::VERBOSE=$verbose;

if ((defined $showInputFmt) or (defined $showOutputFmt)) {
  if (defined $showInputFmt) {
    print "input formats MS/MS: ".(join ',',(InSilicoSpectro::Spectra::MSRun::getReadFmtList(), InSilicoSpectro::Spectra::MSMSSpectra::getReadFmtList()))."\n";
  }
  if (defined $showOutputFmt) {
    print "output formats MS/MS: ".(InSilicoSpectro::Spectra::MSRun::getWriteFmtList(), InSilicoSpectro::Spectra::MSMSSpectra::getWriteFmtList())."\n";
  }
  exit(0);
}

my $run=InSilicoSpectro::Spectra::MSRun->new();
$run->set('defaultCharge', InSilicoSpectro::Spectra::MSSpectra::string2chargemask($defaultCharge));
$run->set('title', $title);

@skip = split(/,/,join(',',@skip));
foreach (@skip) {
  $_=lc $_;
  s/^ms$/pmf/;
  $run->{read}{skip}{$_}=1;
}
my $is=0;
foreach (@fileIn) {
  s/ /\\ /g;
  foreach my $fileIn (glob $_) {
    my $inFormat;
    if ($fileIn=~/(.*?):(.*)/) {
      $run->set('format', $1);
      $run->set('source', ($2 or \*STDIN));
      $inFormat=$1;
    } else {
      $run->set('source', $fileIn);
      $inFormat=InSilicoSpectro::Spectra::MSSpectra::guessFormat($fileIn);
    }
    unless (defined $InSilicoSpectro::Spectra::MSRun::handlers{$inFormat}{read}) {
      my %h;
      foreach (keys %$run) {
	next if /^spectra$/;
	$h{$_}=$run->{$_};
      }
      my $sp=InSilicoSpectro::Spectra::MSSpectra->new(%h);
      $run->addSpectra($sp);
      $sp->set('sampleInfo', \%sampleInfo) if defined %sampleInfo;
      $sp->setSampleInfo('sampleNumber', $is++);
      $sp->open();
    } else {
      croak "not possible to set multiple file in with format [$inFormat]" if $#fileIn>0;
      $InSilicoSpectro::Spectra::MSRun::handlers{$inFormat}{read}->($run);
    }
  }
}
#to filter the spectra
if ($fileFilter) {
  my $fc = new InSilicoSpectro::Spectra::Filter::MSFilterCollection();
  $fc->readXml($fileFilter);
  $fc->filterSpectra($run);
}
if ($precursorTrustParentCharge){
  if($precursorTrustParentCharge eq 'medium'){
    my $origpd_cmask;
    my $alterpd_charge;
    my $imax=$run->getNbSpectra()-1;
    foreach my $i(0..$imax){
      my $sp=$run->getSpectra($i);
      next unless ref($sp) eq 'InSilicoSpectro::Spectra::MSMSSpectra';
      my $jmax=$sp->size()-1;
      for my $j (0..$jmax){
	my $cmpd=$sp->get('compounds')->[$j];
	my $ipdcmask=$cmpd->get('parentPD')->getFieldIndex('chargemask');
	unless(defined $ipdcmask){
	  my $ipdcharge=$cmpd->get('parentPD')->getFieldIndex('charge') or die "neither charge not chargemask is defined for cmpd parent \n$cmpd";
	  if($cmpd->get('parentPD')."" ne "$origpd_cmask"){
	    $origpd_cmask=$cmpd->get('parentPD');
	    $alterpd_charge=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new($origpd_cmask);
	    $alterpd_charge->getFields()->[$ipdcharge]='chargemask';
	    $ipdcmask=$ipdcharge;
	  }else{
	    $alterpd_charge=$cmpd->get('parentPD');
	    $ipdcmask=$ipdcharge;
	  }
	}
	$cmpd->getParentData()->[$ipdcmask]|= (1<<3) if $cmpd->getParentData()->[$ipdcmask] & (1<<2);
	$cmpd->getParentData()->[$ipdcmask]|= (1<<2) if $cmpd->getParentData()->[$ipdcmask] & (1<<3);
      }
    }
  }
}
if($dpmStr){
  use InSilicoSpectro;
  InSilicoSpectro::init();
  die "invalid value [$dpmStr] insteadd of --duplicateprecursormoz=i1:i2" unless $dpmStr=~/^([\-\d]+):([\-\d]+)$/;
  my ($min, $max)=($1, $2);
  my $imax=$run->getNbSpectra()-1;

  my $origpd_cmask;
  my $alterpd_charge;
  foreach my $i(0..$imax){
    my $sp=$run->getSpectra($i);
    next unless ref($sp) eq 'InSilicoSpectro::Spectra::MSMSSpectra';
    my $jmax=$sp->size()-1;
    for my $j (0..$jmax){
      my $cmpd=$sp->get('compounds')->[$j];

      my @charges=$cmpd->precursor_charges();
      die "cannot duplicate with undefined precursor charges" unless @charges;
      foreach my $c(@charges){
	my $ipdcharge=$cmpd->get('parentPD')->getFieldIndex('charge');
	unless(defined $ipdcharge){
	  my $ipdcmask=$cmpd->get('parentPD')->getFieldIndex('chargemask') or die "neither charge not chargemask is defined for cmpd parent \n$cmpd";
	  if($cmpd->get('parentPD')."" ne "$origpd_cmask"){
	    $origpd_cmask=$cmpd->get('parentPD');
	    $alterpd_charge=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new($origpd_cmask);
	    $alterpd_charge->getFields()->[$ipdcmask]='charge';
	    $ipdcharge=$ipdcmask;
	  }else{
	    $alterpd_charge=$cmpd->get('parentPD');
	    $ipdcharge=$ipdcmask;
	  }
	}
	foreach my $shift($min..$max){
	  next if $shift==0;
	  my $newcmpd=InSilicoSpectro::Spectra::MSMSCmpd->new($cmpd);
	  my @prec=@{$cmpd->getParentData()};
	  $newcmpd->setParentData(\@prec);
	  $newcmpd->set('parentPD', $alterpd_charge);
	  $prec[$ipdcharge]=$c;
	  $prec[0]+=InSilicoSpectro::InSilico::MassCalculator::getMass('el_H+')*$shift/$c;
	  $newcmpd->title(($cmpd->title() || "")." [".(($shift>0)?"+":"")."$shift isotope]");
	  $sp->addCompound($newcmpd);
	}
      }
    }
  }
}

my ($outformat, $outfile);
if ($fileOut=~/(.*?):(.*)/) {
  $outformat=$1;
  $outfile=($2 or \*STDOUT);
} else {
  $outfile=$fileOut;
  $outformat=InSilicoSpectro::Spectra::MSSpectra::guessFormat($outfile);
}

# use Data::Dumper;
# $Data::Dumper::Maxdepth=3;
# print Dumper($run);
# use Devel::Size qw(size total_size);

# InSilicoSpectro::Utils::FileCached::dump_all();

# print "mrun total_size=".total_size($run)."\n";


$run->write($outformat, ">$outfile");
