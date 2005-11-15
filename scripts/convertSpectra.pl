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

=item --sampleinfo='name1=val1[;name2=val2[...]]'

Set sample related info example 'instrument=QTOF;instrumentId=xyz'

=item --skip=[msms|pmf]

Do not read msms or pmf information

=item --showinputformats

Prints all the possible format for input

=item --showoutputformats

Prints all the possible format for output

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



BEGIN{
  push @INC, '../../lib';
}

END{
}


use Getopt::Long;
my(@fileIn, $fileOut, $showInputFmt, $showOutputFmt, $sampleInfo, $defaultCharge, $title, @skip, $phenyxConfig, $help, $man, $verbose);

if (!GetOptions(
		"in=s@"=>\@fileIn,
		"out=s"=>\$fileOut,
		"sampleinfo=s"=>\$sampleInfo,
		"showinputformats"=>\$showInputFmt,
		"showoutputformats"=>\$showOutputFmt,

		"defaultcharge=s"=>\$defaultCharge,
		"title=s"=>\$title,

		"skip=s@"=>\@skip,
		"phenyxconfig=s" => \$phenyxConfig,
                "help" => \$help,
                "man" => \$man,
                "verbose" => \$verbose,
               )
    || $help || $man || (((not @fileIn) || (not $fileOut)) and  (not $showInputFmt) and (not $showOutputFmt))){


  pod2usage(-verbose=>2, -exitval=>2) if(defined $man);
  pod2usage(-verbose=>1, -exitval=>2);
}

my %sampleInfo;
foreach(split /;/, $sampleInfo){
  my($n, $v)=split /=/, $_, 2;
  $sampleInfo{$n}=$v;
}

use InSilicoSpectro::Spectra::MSRun;
use InSilicoSpectro::Spectra::MSSpectra;
eval{
  $InSilicoSpectro::Utils::io::VERBOSE=$verbose;

  if((defined $showInputFmt) or (defined $showOutputFmt)){
    if(defined $showInputFmt){
      print "input formats MS/MS: ".(join ',',(InSilicoSpectro::Spectra::MSRun::getReadFmtList(), InSilicoSpectro::Spectra::MSMSSpectra::getReadFmtList()))."\n";
    }
    if(defined $showOutputFmt){
      print "output formats MS/MS: ".(InSilicoSpectro::Spectra::MSRun::getWriteFmtList(), InSilicoSpectro::Spectra::MSMSSpectra::getWriteFmtList())."\n";
    }
    exit(0);
  }

  my $run=InSilicoSpectro::Spectra::MSRun->new();
  $run->set('defaultCharge', InSilicoSpectro::Spectra::MSSpectra::string2chargemask($defaultCharge));
  $run->set('title', $title);

  @skip = split(/,/,join(',',@skip));
  foreach (@skip){
    $_=lc $_;
    s/^ms$/pmf/;
    $run->{read}{skip}{$_}=1;
  }
  my $is=0;
  foreach (@fileIn){
    foreach my $fileIn (glob $_) {
      my $inFormat;
      if ($fileIn=~/(.*):(.*)/) {
	$run->set('format', $1);
	$run->set('source', ($2 or \*STDIN));
	$inFormat=$1;
      } else {
	$run->set('source', $fileIn);
	$inFormat=InSilicoSpectro::Spectra::MSSpectra::guessFormat($fileIn);
      }
      unless (defined $InSilicoSpectro::Spectra::MSRun::readHandlers{$inFormat}) {
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
	$InSilicoSpectro::Spectra::MSRun::readHandlers{$inFormat}->($run);
      }
    }
  }
  my ($outformat, $outfile);
  if($fileOut=~/(.*):(.*)/){
    $outformat=$1;
    $outfile=($2 or \*STDOUT);
  }else{
    $outfile=$fileOut;
    $outformat=InSilicoSpectro::Spectra::MSSpectra::guessFormat($outfile);
  }

  $run->write($outformat, ">$outfile");
};

if ($@){
  print STDERR "error trapped in main\n";
  carp $@;
}
 
