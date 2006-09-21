use strict;

package InSilicoSpectro::Spectra::MSSpectra;
#use UNIVERSAL qw(isa);

use InSilicoSpectro::Spectra::ExpSpectrum;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK, %hFmt, %handlers);
@ISA=qw (InSilicoSpectro::Spectra::ExpSpectrum);
@EXPORT=qw(&string2chargemask &chargemask2string &charge2mgfStr &guessFormat &getFmtDescr);
@EXPORT_OK=qw();

=head1 MSSpectra

General framework for ms spectra

=head1 METHODS

=head1 my $sp=InSilicoSpectro::Spectra::MSSpectra->new(%h|ExpSpectrum|MSSpectra)

=head1 my $sp->source ([$filename])

Set or get the source file (where the data is)

=head1 my $sp->origFile([$filename])

Set or get the original file (where the data was)

=head1 my $sp->format ([$strinf])

Set or get the source file format

=head1 my $sp->title([$string])

Set or get the title

=head1 my $sp->defaultCharge ([$string])

Set or get the defaultCharge

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

use Carp;
use Time::localtime;
use InSilicoSpectro::Utils::io;
use InSilicoSpectro::Spectra::PhenyxPeakDescriptor;
use InSilicoSpectro::Spectra::MSMSSpectra;

%hFmt=(
       dta=>{
	     type=>'msms',
	     ref=>"InSilicoSpectro::Spectra::MSMSSpectra"
	    },
       pkl=>{
	     type=>'msms',
	     ref=>"InSilicoSpectro::Spectra::MSMSSpectra"
	    },
       mgf=>{
	     type=>'msms',
	     ref=>"InSilicoSpectro::Spectra::MSMSSpectra"
	    },
       'mgf.pmf'=>{
	     type=>'msms',
	     ref=>"InSilicoSpectro::Spectra::MSSpectra"
	    },
       'peptMatches'=>{
			   type=>'msms',
			   ref=>"InSilicoSpectro::Spectra::MSMSSpectra"
	    },
       btdx=>{
	     type=>'msms',
	     ref=>"InSilicoSpectro::Spectra::MSMSSpectra"
	    },
      );

%handlers=(
	   txt=>{write=>\&writeTxt,
		},
	   mgf=>{
		 write=>\&writeMGF,
		 description=>"Mascot generic format (mgf)"
		},
	   'mgf.pmf'=>{read=>\&readMGF,
		       write=>\&writeMGF,
		       description=>"Mascot generic format (mgf)"
		      },
	      );


sub new{
  my $class=shift;

  my $spec={spectra=>[]};
  bless $spec, $class;
  if (ref($_[0]) && (ref($_[0]) ne 'HASH') && $_[0]->isa('InSilicoSpectro::Spectra::ExpSpectrum')){
    %$spec = %{$_[0]};
  }
  elsif (ref($_[0]) && (ref($_[0]) ne 'HASH') && $_[0]->isa('InSilicoSpectro::Spectra::MSSpectra')){
    %$spec = %{$_[0]};
  }
  else{
    my %h=(ref($_[0] eq 'HASH'))?%{$_[0]}:@_;
    foreach (keys(%h)){
      next unless /\S/;
      $spec->$_($h{$_});
    }
  }

  return $spec;
}


#--------------- read subs

=head2 read subs

Alow opening data from various format

=head3 open()

Reads the spectra from $this->source , with type from $this{format}. If the latest is not defined, it will try to mgf ()

=cut

use File::Basename;

sub open{
  my ($this)=@_;

  $this->guessFormat();

  my $fmt=$this->format;
  InSilicoSpectro::Utils::io::croakIt "unknown spectra format [$fmt]" unless defined $hFmt{$fmt};
  #croak ($InSilicoSpectro::Utils::io::VERBOSE?("<pre>".Carp::longmess(__PACKAGE__."(".__LINE__."): unknown spectra format [$fmt]\n")."\n</pre>\n"):(__PACKAGE__."(".__LINE__."): unknown spectra format [$fmt]")) unless defined $hFmt{$fmt};
  bless $this, $hFmt{$this->format}{ref};

  $this->read();
}

=head3 guessFormat()

Try to guess the spectra format (if it is not yet defined) based on the file extension stores in the argument {source}. However, if you wish to load for example .dta file from a directory, it will not determine it automatically.

If the format was already specified, it will not try to guess it.

=cut

sub guessFormat{
  my ($this)=@_;

  my $src;
  my $isobj;
  if((ref $this) eq 'InSilicoSpectro::Spectra::MSSpectra'){
    return if defined $this->{format};
    $this->source($src) or croak "InSilicoSpectro::Spectra::MSSpectra:guessFormat not possible as not source was defined";
    $isobj=1;
  }else{
    $src=$this;
  }
  foreach (qw(idj.xml ple.xml peptMatches.xml mgf dta pkl txt)){
    if($src=~/\.$_/i){
      my $fmt=$_;
      $fmt=~s/\.xml$//;
      $this->format($fmt) if $isobj;
      return $fmt;
    }
  }
  croak "InSilicoSpectro::Spectra::MSSpectra:guessFormat not possible as not source [$src] is not within the known formats";
}


#--------------- getters /setters


sub set{
  my ($this, $name, $val)=@_;
  $this->{$name}=$val;
}

sub setSampleInfo{
  my ($this, $name, $val)=@_;
  $this->{sampleInfo}{$name}=$val;
}


sub get{
  my ($this, $name)=@_;
  return $this->{$name};
}

sub srcFile{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{srcFile}=$val;
  }
  return $this->{srcFile};
}

sub source{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{source}=$val;
  }
  return $this->{source};
}

### FIXME
#to ensure correct ExpSpectrum inheritance
sub spectra{
  my ($this, $val) = @_;
  return $this->spectrum($val);

#  if (defined($val)){
#    $this->{spectra}=$val;
#  }
#  return $this->{spectra};
}
####

sub origFile{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{origFile}=$val;
  }
  return $this->{origFile};
}

sub format{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{format}=$val;
  }
  return $this->{format};
}

sub title{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{title}=$val;
  }
  return $this->{title};
}

sub defaultCharge{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{defaultCharge}=$val;
  }
  return $this->{defaultCharge};
}

#--------------- I/O

use SelectSaver;
sub write{
  my ($this, $format, $out)=@_;
  croak "InSilicoSpectro::Spectra:MSMSSpectra:write: no handler defined for format [$format] (".getWriteFmtList().")\n" unless defined $handlers{$format}{write};

  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD(">$out") or die "cannot open [$out]: $!")) if defined $out;
  $handlers{$format}{write}->($this);
}

sub writeTxt{
  my ($this)=@_;
  print "#sampleNumber=".$this->get('sampleNumber')."\n";
  foreach(@{$this->spectrum()}){
    print "".(join ' ', @$_)."\n";
  }
  print "\n";
}

sub writeMGF{
  my ($this)=@_;
  warn "NO writeMGF fo MSSpectra implemeneted";
  return;
}

sub writePLE{
  my ($this, $shift)=@_;
  my $transformChargeMask=1;

print "$shift<ple:PeakListExport spectrumType=\"ms\" xmlns:ple=\"http://www.phenyx-ms.com/namespaces/PeakListExport.html\">
$shift  <ple:date>".($this->get('date'))."</ple:date>
$shift  <ple:time>".($this->get('time'))."</ple:time>
$shift  <ple:PeakDetectionAlg>
$shift    <ple:ProgramName>InSilicoSpectro::Spectra::MSSpectra</ple:ProgramName>
$shift    <ple:ProgramVersion>$InSilicoSpectro::VERSION</ple:ProgramVersion>
$shift    <ple:ProgramParameters>
$shift      <ple:PParam name=\"source\" value=\"".$this->source."\"/>
$shift    </ple:ProgramParameters>
$shift  </ple:PeakDetectionAlg>
$shift  <ple:PeakLists>
";
  $this->get('peakDescriptor')->writeXml("$shift  ", $transformChargeMask);
  print "$shift    <ple:MSRun>
";
  #print sample line
  if(defined $this->get('sampleInfo')){
    my $h=$this->get('sampleInfo');
    print "$shift      <ple:sample";
    foreach (keys %$h){
      print " $_=\"$h->{$_}\"";
    }
    print "/>\n";
  }else{
    croak "No sample info available when saving to ple ".$this->source;
  }
  #print
  if(defined $this->get('wellInfo')){
  my $h=$this->get('wellInfo');
    print "$shift      <ple:$_>$h->{$_}</ple:$_>\n";
  }
  print "$shift      <ple:AcquNumber>".$this->get('AcquNumber')."</ple:AcquNumber>\n" if defined $this->get('AcquNumber');
  print "$shift      <ple:peaks><![CDATA[\n";

  if(defined $this->spectrum()){
    foreach (@{$this->spectrum()}){
      print "".(join "\t", @$_)."\n";
    }
  }
   print "]]></ple:peaks>\n";
  print "$shift    </ple:MSRun>
$shift  </ple:PeakLists>
$shift</ple:PeakListExport>
";
}

sub read{
  my ($this)=@_;

  my $fmt=$this->format();
  croak "InSilicoSpectro::Spectra::MSSpectra: no reading handler is defined for format [$fmt]" unless defined $handlers{$fmt}{read};


  my $h=$this->get('sampleInfo');
  if(defined $h){
    $h->{sampleNumber}=0 unless defined $h->{sampleNumber};
    $h->{instrument}='n/a' unless defined $h->{instrument};
    $h->{instrumentId}='n/a' unless defined $h->{instrumentId};
    $h->{spectrumType}='pmf' unless defined $h->{spectrumType};
  }else{
    $this->set('sampleInfo', {sampleNumber=>0, instrument=>"n/a", instrumentId=>"n/a", spectrumType=>"pmf"});
  }
  $handlers{$fmt}{read}->($this);
}

sub readMGF{
  my ($this)=@_;
  my $src=$this->source();
  my $fd;
  CORE::open ($fd, "<$src") or croak "cannot open [<$src]: $!";

  my $pd=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity");
  $this->set('peakDescriptor', $pd);

  $this->set('jobId', (basename $src));
  $this->set('date', sprintf("%4d-%2.2d-%2.2d",localtime->year()+1900, localtime->mon()+1, localtime->mday()));
  $this->set('time',sprintf("%2.2d:%2.2d:%2.2d", localtime->hour(), localtime->min(), localtime->sec()));

  #msms step
  my %md52sp;
  my $iCmpd;
  $this->spectrum([]);
  while(<$fd>){
    chomp;
    s/\s+$//;
    if(/^COM=(.*)/i){
      my $t=$1;
      $t=~s/\s+$//;
      $t=~s/^\s+//;
      $this->set('title', $t)if $t=~/\S/;
      next;
    }
    if(/^([\d\.]+)\s+([\d\.]+)/){
      push @{$this->spectrum()}, [$1, $2];
    }
    last if (/^BEGIN IONS/i);
  }
  close $fd;
}


#--------------- charge subs

=head2 chargeMasks

To allow charge incertitude, the package manage multi charges as on int. For example '2+ AND 3+' will be stored as (2^2+2^3)=12.
Subroutines to convert string 2 chargeMask are exported as static (they do not belong to one particuliar spectra

=cut

sub string2chargemask{
  my ($str)=@_;
  $str=~s/^\s+//g;
  $str=~s/\s+$//g;
  $str=~s/AND/ /ig;
  $str=~s/[,\+]/ /g;
  $str=~s/^\s+//;
  my $m=0;
  foreach (split /\s+/, $str){
    $m|=(1<<$_);
  }
  return $m;
}
sub chargemask2string{
  my ($msk)=@_;

  return '?' unless defined $msk;

  my $ret;
  for(0..31){
    $ret.="$_," if (1<<$_)&$msk;
  }
  $ret=~s/,$//;
  return $ret;
}

sub charge2mgfStr{
  my $c=$_[0];
  $c=~s/([0-9]+)/$1+/g;
  $c=~s/^1\+,2\+,3\+$/1+, 2+ and 3+/;
  $c=~s/^2\+,3\+$/2+ and 3+/;
  return $c;
}

# -------------------------------   misc
sub getReadFmtList{
  my @tmp;
  foreach (sort keys %handlers){
    push @tmp, $_ if $handlers{$_}{read};
  }
  return wantarray?@tmp:("".(join ',', @tmp));
}

sub getWriteFmtList{
  my @tmp;
  foreach (sort keys %handlers){
    push @tmp, $_ if $handlers{$_}{write};
  }
  return wantarray?@tmp:("".(join ',', @tmp));
}

sub getFmtDescr{
  my $f=shift || croak "must provide a format to getFmtDescr";
  croak "no handler for format=[$f]" unless $handlers{$f};
  return $handlers{$f}{description} || $f;
}

return 1;
 
