use strict;

package InSilicoSpectro::Spectra::MSMSSpectra;
use InSilicoSpectro::Spectra::MSSpectra;
use Carp;

=head1 NAME

InSilicoSpectro::Spectra::MSMSSpectra

=head1 SYNOPSIS

#set new spectra with source
my $sp=InSilicoSpectro::Spectra::MSSpectra->new({source=>$file});
#if the format cannot (or may not) be deduced from the file name, we can set it
$sp->format('dta');
$sp->open();

#convert into another format
$sp->write('idj', "/tmp/a.idj.xml");

=head1 DESCRIPTION

General framework for MS/MS spectra.

This mainly means:

=over 4

=item converting file between several kinds of usual formats.

=back


=head1 FUNCTIONS

=head3 getReadFmtList()

returns the list of data format with available read handlers (known type for input).

=head3 getWriteFmtList()

returns the list of data format with available write handlers (known type for ouput).

=head1 METHODS

=head3 $sp=InSilicoSpectro::Spectra::MSSpectra->new(\%h);

Arguments are through a hash (see $sp->set($name, $val) method.


=head3 $sp->read()


=head3 $sp->set($name, $val)

Set an instance paramter, name can be

=over 4

=item src

the source file (or directory, for .dta)

=item format

input data format such as 'mgf', 'pkl', 'dta', 'idj.xml'.

=item sampleInfo

sampling info. $val is either a reference to a hash, or a string such as 'tag1=value1;tag2=value' (ex='intrument=LCQ;instrumentID=xyz'). Setting sampleInfo will erase the former value (consider $sp->addSampleInfoTag($name, $value) instead;

=back

=head3 $sp->get($name)

Get an instance parameter.

=head3 $sp->getSize()

Returns the number of compounds

=head1 FORMAT NOTEs

=head2 Sequest (dta):

header line format is [M+H]+   charge

rem: native dta contains only one ms/ms spectrum. dtas can be concatenated, separated by one blank line

=head2 Micromass (pkl)

header line format is m/z  intensity charge


=head1 EXAMPLES

set lib/Phenyx/Spectra/test directory

=head1 SEE ALSO

InSilicoSpectro::Spectra::MSSpectra InSilicoSpectro::Spectra::MSMSCmpd, Phenyx::Config::GlobalParam


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

Alexandre Masselot, Pierre-Alain Binz, www.genebio.com

=cut


require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK, %handlers);
@ISA=qw(InSilicoSpectro::Spectra::MSSpectra);
@EXPORT=qw(&getReadFmtList &getwriteFmtList &getFmtDescr);
@EXPORT_OK=qw();



use InSilicoSpectro::Utils::io;
use InSilicoSpectro::Spectra::PhenyxPeakDescriptor;
use InSilicoSpectro::Spectra::MSMSCmpd;
#use Phenyx::Config::GlobalParam;

%handlers=(
	   dta=>{read=>\&readDTA,
		},
	   pkl=>{read=>\&readDTA,
		},
	   mgf=>{read=>\&readMGF,
		 write=>\&writeMGF,
		 description=>"Mascot generic format (mgf)"
		},
	   btdx=>{read=>\&readBTDX,
		  description=>"Bruker BTDX"
		 },
#	   mzdata=>{read=>\&readMzData,
#		   },
#	   mzxml=>{read=>\&readMzXml,
#		  },
	   peptMatches=>{read=>\&readPeptMatchesXml,
			},
	   ple=>{write=>\&writePLE,
		 description=>"Phenyx peaklist (ple)"
		},
	   idj=>{write=>\&writeIDJ,
		 description=>"Phenyx experimental data (idj)"
		}
	      );

sub new{
  my ($class, $h) = @_;

  my $dvar = {};
  bless $dvar, $class;

  if(defined $h){
    if((ref $h)eq 'HASH'){
      foreach (keys %$h){
	$dvar->set($_, $h->{$_});
      }
    }elsif((ref $h)eq $class){
      foreach (keys %$h){
	$dvar->set($_, $h->{$_}); 
      }
    }else{
      die "cannot instanciate new $class with arg of type [".(ref $h)."]";
    }
  }
  return $dvar;
}


#----------------------- readers


sub read{
  my ($this)=@_;

  my $fmt=$this->format();
  croak "InSilicoSpectro::Spectra::MSMSSpectra: no reading handler is defined for format [$fmt]" unless defined $handlers{$fmt}{read};


  my $h=$this->get('sampleInfo');
  if(defined $h){
    $h->{sampleNumber}=0 unless defined $h->{sampleNumber};
    $h->{instrument}='n/a' unless defined $h->{instrument};
    $h->{instrumentId}='n/a' unless defined $h->{instrumentId};
    $h->{spectrumType}='msms' unless defined $h->{spectrumType};
  }else{
    $this->set('sampleInfo', {sampleNumber=>0, instrument=>"n/a", instrumentId=>"n/a", spectrumType=>"msms"});
  }
  $handlers{$fmt}{read}->($this);
}

sub readTwigEl{
  my ($this, $el)=@_;
  my $pd=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new();
  $this->set('jobId',$el->get_xpath("idj:JobId"));
  $this->set('date', $el->get_xpath("idj:date"));
  $this->set('time', $el->get_xpath("idj:time"));

  my $elpl=$el->first_child("ple:PeakLists");
  $pd->readTwigEl($elpl->first_child("ple:ItemOrder"));
  $this->set('parentPD', $pd);
  $this->set('fragPD', $pd);

  my $elsi=($elpl->get_xpath("ple:MSMSRun/ple:sample"))[0];
  foreach ($elsi->att_names){
    $this->setSampleInfo($_, $elsi->att($_));
  }
  my @cmpds=$elpl->get_xpath("ple:MSMSRun/ple:peptide");
  foreach(@cmpds){
    my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new;
    $cmpd->readTwigEl($_, $pd, $pd);
    $this->addCompound($cmpd);
  }
}


#############  peptMatchesXml
sub readPeptMatchesXml{
 my ($this)=@_;
 my $file=$this->source();
  my $twig=XML::Twig->new(twig_handlers=>{
					  'idi:header'=>sub {twigPMHeader($this, $_[0], $_[1])},
					  'idi:OneIdentification'=>sub {twigPMCmpd($this, $_[0], $_[1])},
					  pretty_print=>'indented'
					 }
			 );
  print STDERR "xml parsing [$file]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
  $twig->parsefile($file) or croak "cannot parse [$file]: $!";
}

sub twigPMHeader{
  my ($this, $t, $el)=@_;
  $this->set('jobId', 'n/a');
  $this->set('date', $el->first_child('idi:date'));
  $this->set('time', $el->first_child('idi:time'));

  my $pd=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new;
  $pd->readTwigEl($el->first_child("ple:ItemOrder"));
  $this->set('parentPD', $pd);
  $this->set('fragPD', $pd);
}

sub twigPMCmpd{
  my ($this, $t, $el)=@_;
  my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new;
  $cmpd->readTwigEl($el->get_xpath("ple:peptide"), $this->get('parentPD'), $this->get('fragPD'));
    $this->addCompound($cmpd);
}
############# EO peptMatchesXml

use File::Basename;
use Time::localtime;
use File::Find::Rule;
use Digest::MD5 qw(md5);
my %md52sp;
sub readDTA{
  my ($this)=@_;

  my $src=$this->source();
  my @files;
  $src=~s/ /\\ /g;
  if(-d $src){
    @files=File::Find::Rule->file()->name( qr/\.dta$/i)->in($src);
    carp "no *.dta  file within $src" unless @files;
  }else{
    push @files, glob $src;
  }

  my $pd=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity chargemask");
  $this->set('parentPD', $pd);
  $this->set('fragPD', $pd);

  $this->set('jobId', (basename $src));
  $this->set('date', sprintf("%4d-%2.2d-%2.2d",localtime->year()+1900, localtime->mon()+1, localtime->mday()));
  $this->set('time',sprintf("%2.2d:%2.2d:%2.2d", localtime->hour(), localtime->min(), localtime->sec()));

  #we have to take care of the same spectra, wich is defined several times with different charges
  my $i;
  my $threeFieldsHeader;
  foreach my $fname(@files){
    open (*fd, "<$fname") or confess "cannot open [$fname]: $!";
    #rem: native dta contains only one ms/ms spectrum. dtas can be concatenated, separated by one blank line
    #local $/;
    my $all;
    my $firstLines=1;
    while(<fd>){
      next if /^#/;
      next if (! /\S/) and $firstLines;
      undef $firstLines;
      s/^\s+(?=\S)//;
      $all.=$_;
    }
    ##################### gap detection (and merging)
    #we must merge gap such as
    #876 123 3
    #234 213
    #236 128
    #
    #247 129
    #251 12
    #
    #1024 345 2
    #where there is a gap in the firest spectra
    my $firstLine=(split /\n/, $all)[0];
    my @tmp=split /\s+/, $firstLine;
    if((scalar @tmp)>2){
      $all=~ s/([^\n]+)\n[\s\n]*\n([^\n]+)/pklContinuity($1, $2)?"$1\n$2":"$1\n\n$2"/eg;
    }

    my $isp=0;
    foreach (split /\n\s*\n+/, $all) {
      print STDERR '.' if(((++$i % 100)==0) && $InSilicoSpectro::Utils::io::VERBOSE);
      s/,/./g;
      my ($head, $contents)=split /\n/, $_, 2;
      $contents =~s/\s+$//;
      my($m, $int, $c)=split /\s+/, $head;
      unless ((defined $m) && (defined $int)){
	warn "invalid spectra headline [$head]";
	next;
      }
      my $defMoz;
      unless($c =~/\S/){
	$c=$int;
	$int=1;
      }else{
	$defMoz=1;
      }

      local $/;
      my $md5=md5($contents);
      my $name=($this->{origFile}||(basename $fname)).".".($isp++);
      if (defined $md52sp{$md5}) {
	my $cmpd=$md52sp{$md5};
	my $msk=$cmpd->getParentData(2);
	$msk|=(1<<$c);
	$cmpd->setParentData(2, $msk);
	$cmpd->set('title', $cmpd->get('title')."//$name");
	#print STDERR "same title for ".($cmpd->get('title'))."\n";
      } else {
	my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new({title=>$name, parentPD=>$pd, fragPD=>$pd});
	$md52sp{$md5}=$cmpd;
	my $moz=$defMoz?$m:($m-1.00728)/$c+1.00728;
	my $cmsk= 1<<$c;
	$cmpd->setParentData([$moz, $int, $cmsk]);
	my @pl;
	foreach (split /\n/, $contents) {
	  my @tmp=split;
	  push @pl,\@tmp;
	}
	$cmpd->set('fragments', \@pl);
    $this->addCompound($cmpd);
      }
    }
    close *fd;
  }
}


#pklContinuity($line1, $line2)
#return 1 <=> looks like it was a nasty hole between to lines that seems to be part of the same frag spectra
sub pklContinuity{
  my ($l, $k)=@_;
  my @l=split /\s+/, $l;
  my @k=split /\s+/, $k;
  #print "[".(join ':', @l)."][".(join ':', @l)."]\n";
  return 0 if (scalar @k)>2;
  return 0 if (scalar @l)!=(scalar @k); #if the number of field is different (case of pkl header)
  return 1;
}

sub readMGF{
  my ($this)=@_;
  my $src=$this->source();
  open (*fd, "<$src") or croak "cannot open [<$src]: $!";

  my $pd=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity chargemask");
  $this->set('parentPD', $pd);
  $this->set('fragPD', $pd);

  $this->set('jobId', (basename $src));
  $this->set('date', sprintf("%4d-%2.2d-%2.2d",localtime->year()+1900, localtime->mon()+1, localtime->mday()));
  $this->set('time',sprintf("%2.2d:%2.2d:%2.2d", localtime->hour(), localtime->min(), localtime->sec()));

  #msms step
  my %md52sp;
  my $iCmpd;
  while(<fd>){
    chomp;
    s/\s+$//;
    if (/^CHARGE=(.*)/i) {
      $this->set('defaultCharge', InSilicoSpectro::Spectra::MSSpectra::string2chargemask($1));
      next;
    }
    if (/^COM=(.*)/i) {		#replace jobId by the COM tag if it is not empty
      $this->set('jobId', $1) if $1 =~/\S/;
      next;
    }
    if (/^BEGIN IONS/i) {
      $iCmpd++;
      my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new({title=>(basename $src)."($iCmpd)", parentPD=>$pd, fragPD=>$pd});
      my $charge=$this->get('defaultCharge');
      my ($moz, $int)=(-1, 1);
      my @pl;
      while (<fd>) {
	chomp;
	next unless /\S/;
	if(/^TITLE=(.*)/i){
	  my $t=$1;
	  $t=~s/\s+$//;
	  $t=~s/^\s+//;
	  $cmpd->set('title', $t)if $t=~/\S/;
	  next;
	}
	if (/^CHARGE=(.*)/i) {
	  $charge= InSilicoSpectro::Spectra::MSSpectra::string2chargemask($1);
	  next;
	}
	if(/^PEPMASS=(.*)/i){
	  my $t=$1;
	  $t=~s/^\s+//;
	  ($moz, $int)=split /\s+/, $t;
	  $int=(100+$moz/1000)  unless $int;
	  next;
	}
	if(/^\s*[0-9]/){
	  s/,/./g;
	  my ($moz, $int, $charge)=split;
	  next if $moz<1.;
	  $charge=InSilicoSpectro::Spectra::MSSpectra::string2chargemask($charge);
	  $int=(100+$moz/1000) unless defined $int;
	  $charge='?' unless $charge;
	  push @pl, [$moz, $int, $charge];
	  next;
	}
	if (/^END IONS/i) {
	  carp "neither charge or default charge is defined for compound #$iCmpd" unless $charge;
	  my $pd=$cmpd->get('parentData');
	  my $contents="$pd->[0]:$pd->[1]:x";
	  foreach(@pl){
	    $contents.="\n".(join ':', @$_);
	  }
	  my $md5=md5($contents);
	  if (defined $md52sp{$md5}) {
	    my $cmpd=$md52sp{$md5};
	    my $msk=$cmpd->getParentData(2);
	    $msk|=$charge;
	    $cmpd->setParentData(2, $msk);
	    $cmpd->set('title', $cmpd->get('title')."(*)");
	  }else{
	    $cmpd->set('parentData', [$moz, $int, $charge]);
	    $md52sp{$md5}=$cmpd;
	    $cmpd->set('fragments', \@pl);
	    $this->addCompound($cmpd);
	  }
	  last;
	}
      }
    }
  }
  close *fd;
}

#--------------- BTDX format 
my %itemSortIndex=(
		   mass=>0,
		   intensity=>1,
		   charge=>2
		  );
sub sortIndex{
  my($a, $b)=@_;
  return $a cmp $b unless (defined $itemSortIndex{$a}) or (defined $itemSortIndex{$b});
  return -1 unless defined $itemSortIndex{$b};
  return 1 unless defined $itemSortIndex{$a};
  return $itemSortIndex{$a}<=>$itemSortIndex{$b};
}
my %btdxConversionItems=(
			 mz=>'mass',
			 z=>'charge',
			 i=>'intensity',
			 sn=>'snratio',
			);

my $twigBtdxPeakDescriptor;
my $twigBtdxPeakDescriptorStr;
my @twigBtdxPeakAtt;
my $twigBtdxPeakAttChargeIndex;
use XML::Twig;
sub readBTDX{
  my ($this)=@_;

  my $src=$this->source();
  croak "input file [$src] is not readable" unless -r $src;
  my $twig=XML::Twig->new(twig_handlers=>{
					  'cmpd'=>sub {twigBtdxReadCmpd($this, $_[0], $_[1])}
					 }
			 );
  print STDERR "xml parsing [$src]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
  $twig->parsefile($src) or croak "cannot parse [$src]: $!";
}

sub twigBtdxReadCmpd{
  my ($this, $t, $el)=@_;
#  my @tmp=qw(intensity mass charge pouet mass machin);
#  print "sorted:".(join ':', (sort {sortIndex($a, $b)} @tmp))."\n";

  my $prec=$el->first_child("precursor");
  unless(defined $twigBtdxPeakDescriptor){
    $twigBtdxPeakDescriptorStr=twigBtdxAtt2PeakDecriptorString($prec);
    print STDERR "twigBtdxPeakDescriptorStr=[$twigBtdxPeakDescriptorStr]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
    $twigBtdxPeakDescriptor=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new($twigBtdxPeakDescriptorStr);
    $this->set('parentPD', $twigBtdxPeakDescriptor);
    my %h=reverse %btdxConversionItems;
    my $i=0;
    foreach (split /\s+/, $twigBtdxPeakDescriptorStr){
      push @twigBtdxPeakAtt, $h{$_};
      $twigBtdxPeakAttChargeIndex=$i if($_ eq 'charge');
      $i++;
    }
    print STDERR "attibute order [".(join ':', @twigBtdxPeakAtt)."]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
  }else{
    my $s=twigBtdxAtt2PeakDecriptorString($prec);
    croak "cannot handle different set of peak attributes [$s]/[$twigBtdxPeakDescriptorStr] (line=".$t->current_line. " col=".$t->current_column.")" if $s ne $twigBtdxPeakDescriptorStr;
  }
  my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new({parentPD=>$twigBtdxPeakDescriptor, fragPD=>$twigBtdxPeakDescriptor});
  $cmpd->set('title', $el->first_child('title')->text);
  if($prec->{att}->{rt_unit} eq 's'){
    $cmpd->set('acquTime', $prec->{att}->{rt});
  }

  my @tmp;
  foreach(sort {sortIndex($a, $b)} $el->first_child('precursor')->att_names){
    foreach(@twigBtdxPeakAtt){
      my $v=$prec->{att}->{$_};
      if($_ eq 'z'){
	$v=~ s/\+//;
      }
      push @tmp, (defined $v)?$v:'?';
    }
  }
#  $tmp[$twigBtdxPeakAttChargeIndex]=InSilicoSpectro::Spectra::MSSpectra::string2chargemask($tmp[$twigBtdxPeakAttChargeIndex]) if defined $twigBtdxPeakAttChargeIndex;
  $cmpd->set('parentData', \@tmp);

  #avoid peak unless defined fragmentation data
  next unless defined $el->first_child('ms_spectrum');
  my @peaksEl=$el->get_xpath('ms_spectrum[@msms_stage="2"]/ms_peaks/pk');
  my @pl;
  foreach my $pkel(@peaksEl){
    my @tmp;
    foreach(@twigBtdxPeakAtt){
      my $v=$pkel->{att}->{$_};
      if($_ eq 'z'){
	$v=~ s/\+//;
      }
      push @tmp, (defined $v)?$v:'?';
    }
#    $tmp[$twigBtdxPeakAttChargeIndex]=InSilicoSpectro::Spectra::MSSpectra::string2chargemask($tmp[$twigBtdxPeakAttChargeIndex]) if defined $twigBtdxPeakAttChargeIndex;
    push @pl, \@tmp;
  }
  $cmpd->set('fragments', \@pl);
  $this->addCompound($cmpd);

}
sub twigBtdxAtt2PeakDecriptorString{
  my($el)=@_;
  my @tmp;
  foreach($el->att_names){
    if(defined $btdxConversionItems{$_}){
      push @tmp, $btdxConversionItems{$_};
    }
  }
  push @tmp, 'charge'  unless defined $el->atts->{z};
  return (join " ", (sort {sortIndex($a, $b)} @tmp));
}

#---------------------- end of BTDX
#--------------- mzxml format

#---------------------- end of mzxml

#--------------- mzdata format


#---------------------- end of mzdata


#--------------- writers
use SelectSaver;
sub write{
  my ($this, $format, $out)=@_;
  croak "InSilicoSpectro::Spectra:MSMSSpectra:write: no handler defined for format [$format] (".getWriteFmtList().")\n" unless defined $handlers{$format}{write};

  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD(">$out") or die "cannot open [$out]: $!")) if defined $out;
  $handlers{$format}{write}->($this);
}

#sub writeIDJ{
#  my ($this, $shift)=@_;

#  print "$shift<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
#$shift<idj:IdentificationJob xmlns:idj=\"".(Phenyx::Config::GlobalParam::get('XMLNSHTTP'))."/IdentificationJob.html\">
#$shift  <idj:JobId>".($this->get('jobId'))."</idj:JxbobId>
#$shift  <idj:header>
#$shift    <idj:contents workflowId=\"n/a\" proteinSize=\"n/a\" priority=\"n/a\" request=\"n/a\"/>
#$shift    <idj:date>".($this->get('date'))."</idj:date>
#$shift    <idj:time>".($this->get('time'))."</idj:time>
#$shift  </idj:header>
#$shift  <anl:AnalysisList xmlns:anl=\"".(Phenyx::Config::GlobalParam::get('XMLNSHTTP'))."/AnalysisList.html\">
#";
#  $this->writePLE("$shift    ");
#print "$shift  </anl:AnalysisList>
#$shift</idj:IdentificationJob>
#";
#}


sub writePLE{
  my ($this, $shift)=@_;
  my $transformChargeMask=1;

  $this->{key}="sample_$this->{sampleInfo}{sampleNumber}" unless  $this->{key};

print "$shift<ple:PeakListExport key=\"$this->{key}\" spectrumType=\"msms\" xmlns:ple=\"http://www.phenyx-ms.com/namespaces/PeakListExport.html\">
$shift  <ple:date>".($this->get('date'))."</ple:date>
$shift  <ple:time>".($this->get('time'))."</ple:time>
$shift  <ple:PeakDetectionAlg>
$shift    <ple:ProgramName>InSilicoSpectro::Spectra::MSMSSpectra</ple:ProgramName>
$shift    <ple:ProgramVersion>".$InSilicoSpectro::Version."</ple:ProgramVersion>
$shift    <ple:ProgramParameters>
$shift      <ple:PParam name=\"source\" value=\"".$this->source()."\"/>
$shift    </ple:ProgramParameters>
$shift  </ple:PeakDetectionAlg>
$shift  <ple:PeakLists>
";
  $this->get('parentPD')->writeXml("$shift  ", $transformChargeMask);
  print "$shift    <ple:MSMSRun>
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
    croak "No sample info available when saving to ple ".$this->source();
  }
  #print
  if(defined $this->get('wellInfo')){
  my $h=$this->get('wellInfo');
    print "$shift      <ple:$_>$h->{$_}</ple:$_>\n";
  }
  print "$shift      <ple:AcquNumber>".$this->get('AcquNumber')."</ple:AcquNumber>\n" if defined $this->get('AcquNumber');
  if(defined $this->get('compounds')){
    foreach (@{$this->get('compounds')}){
      $_->writePLE("$shift      ", $transformChargeMask);
    }
  }
  print "$shift    </ple:MSMSRun>
$shift  </ple:PeakLists>
$shift</ple:PeakListExport>
";
}

sub writeMGF{
  my ($this)=@_;
  my $transformChargeMask=1;
  if(defined $this->get('compounds')){
    foreach (@{$this->get('compounds')}){
      $_->writeMGF($transformChargeMask);
    }
  }
}
#---------------

sub makePmf{
  my ($this)=@_;

  my %h;
  foreach (keys %$this){
    $h{$_}=$this->{$_};
  }
  my $pmf=InSilicoSpectro::Spectra::MSSpectra->new(\%h);
  $pmf->{sampleInfo}={};
  foreach (keys %{$this->{sampleInfo}}){
    $pmf->{sampleInfo}{$_}=$this->{sampleInfo}{$_};
  }
  undef $pmf->{compounds};
  undef $pmf->{parentPD};
  undef $pmf->{fragPD};
  $pmf->{peakDescriptor}=$this->{parentPD};
  undef $pmf->{compounds};
  $pmf->{peaks}=[];
  if(defined $this->get('compounds')){
    foreach (@{$this->get('compounds')}){
      push @{$pmf->{peaks}}, $_->getParentData();
    }
  }
  $pmf->setSampleInfo('spectrumType', 'ms');
  return $pmf;
}

#--------------- getters /setters

sub set{
  my ($this, $name, $val)=@_;

  if ($name eq 'sampleInfo'){
    $this->{sampleInfo}={};
    if((ref $val) eq 'HASH'){
      foreach (keys %$val){
	$this->addSampleInfoTag($_, $val->{$_});
      }
    }else{
      foreach (split /;/, $val){
	my ($n, $v)=split /=/, $_, 2;
	$this->addSampleInfoTag($n, $v);
      }
    }
    return;
  }
  $this->{$name}=$val;
}

sub addSampleInfoTag{
  my ($this, $name, $val)=@_;
  $this->{sampleInfo}{$name}=$val;
}

sub addCompound{
  my ($this, $cmpd)=@_;
  $cmpd->{key}="sample_$this->{sampleInfo}{sampleNumber}%"."cmpd_".($this->getSize()||0) unless defined $this->{key};
  $cmpd->title2acquTime;
  push @{$this->{compounds}}, $cmpd;
}

sub get{
  my ($this, $name)=@_;
  return $this->{$name};
}

### FIXME
#to ensure correct ExpSpectrum inheritance
sub spectrum{
  my ($this, $val) = @_;

  if (defined($val)){
    $this->{compounds}=$val;
  }
  return $this->{compounds};
}

####

###FIXME change into size()
sub getSize{
  my $this=$_[0];
  return (defined $this->{compounds})?(scalar @{$this->{compounds}}):undef;
}
sub size{
  return $_[0]->getSize();
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


1;
