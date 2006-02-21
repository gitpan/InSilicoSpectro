use strict;

package InSilicoSpectro::Spectra::MSRun;
require Exporter;
use Carp;

=head1 NAME

InSilicoSpectro::Spectra::MSRun

=head1 SYNOPSIS


=head1 DESCRIPTION

A MSRun is a collection of MSSpectra (either ms or ms/ms)

=head1 FUNCTIONS

=head3 getReadFmtList()

Returns the list of data format with available read handlers (known type for input).

=head3 getWriteFmtList()

Returns the list of data format with available write handlers (known type for ouput).

=head1 METHODS

=head3 my $run=InSilicoSpectro::Spectra::MSRun->new()

=head3 $run->addSpectra($sp)

Add an InSilicoSpectro::Spectra::MSSpectra (either ms or msms)

=head3 $run->getNbSpectra()

Returns the number of spectra

=head3 $run->getSpectra($i)

Returns the spectra number $i

=head3 $run->readIDJ($file)

=head3 $run->write($format, [$fname|fh]);

=head3 $run->writePle($shift)

Writes the run into a ple format ($shift is typically a string with some space char to have something correctly indented)

=head3 $run->write($format, [$fname|fh])

Write the run on the given format.

=head3 $se->set($name, $val)

Ex: $u->set('date', 'today')

=head3 $se->get($name)

Ex: $u->get('date')

=head1 EXAMPLES


=head1 SEE ALSO

InSilicoSpectro::Spectra::MSSpectra

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

our (@ISA,@EXPORT,@EXPORT_OK, $dbPath);
@ISA = qw(Exporter);

@EXPORT = qw(&getReadFmtList &getwriteFmtList %handlers);
@EXPORT_OK = ();

use File::Basename;

use InSilicoSpectro::Spectra::MSSpectra;
use InSilicoSpectro::Spectra::MSMSSpectra;

our %handlers=(
	       ple=>{
		     write=>\&writePLE,
		     description=>"Phenyx peaklist (ple)",
		    },
	       idj=>{
		     write=>\&writeIDJ,
		     read=>\&readIDJ,
		     description=>"Phenyx spectra data (idj)",
		    },
	       mgf=>{
		     write=>\&writeMGF
		    },
	       mzxml=>{
		       read=>\&readMzXml,
		      },
	       mzdata=>{
			read=>\&readMzData,
			description=>"mzdata (version >= 1.05)",
		       },
	      );


#my @spectra;

sub new{
  my ($pkg, $h)=@_;

  my $dvar={};
  bless $dvar, $pkg;

  foreach (keys %$h){
    $dvar->set($_, $h->{$_});
  }
  $dvar->{spectra}=[];

  return $dvar;
}

sub addSpectra{
  my($this, $sp)=@_;
  push @{$this->{spectra}}, $sp;
}

sub getNbSpectra{
  my ($this)=@_;
  return (defined $this->{spectra})?(scalar @{$this->{spectra}}):0;
}

sub getSpectra{
  my ($this, $i)=@_;
  return (defined $this->{spectra})?($this->{spectra}->[$i]):undef;
}

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


use XML::Twig;

############## IDJ format
sub readIDJ{
  my ($this, $file)=@_;

  $file=$this->{source} unless defined $file;
  my $twig=XML::Twig->new(twig_handlers=>{
					  'ple:PeakListExport'=>sub {twig_addSpectrum($this, $_[0], $_[1])},
					  'idj:JobId'=>sub {$this->{jobId}=$_[1]->text},
					  'idj:header'=>sub {twig_setHeader($this, $_[0], $_[1])},
					  pretty_print=>'indented'
					 }
			 );
  print STDERR "xml parsing [$file]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
  $twig->parsefile($file) or InSilicoSpectro::Utils::io::croakIt "cannot parse [$file]: $!";
}
sub twig_setHeader{
  my($this, $twig, $el)=@_;
  $this->{time}=$el->first_child('idj:time')->text;
  $this->{date}=$el->first_child('idj:date')->text;
}

sub twig_addSpectrum{
  my($this, $twig, $el)=@_;
  my $type=$el->att('spectrumType') or InSilicoSpectro::Utils::io::croakIt "no spectrumType att for $el";
  my $sp;
  if($type eq 'msms'){
    $sp=InSilicoSpectro::Spectra::MSMSSpectra->new();
    $sp->readTwigEl($el);
  }elsif($type eq 'ms'){
    $sp=InSilicoSpectro::Spectra::MSSpectra->new();
    $sp->readTwigEl($el);
  }else{
    InSilicoSpectro::Utils::io::croakIt "no procedure for type=[$type]";
  }
  $this->addSpectra($sp);
}

#########  mzxml

use Time::localtime;
use MIME::Base64;

use InSilicoSpectro::Spectra::PhenyxPeakDescriptor;

my $spmsms;
my $pd_mzint=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity");
my $pd_mzintcharge=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity chargemask");
my $is=0;

sub readMzXml{
  my ($this, $file)=@_;
  $file=$this->{source} unless defined $file;

  my $twig=XML::Twig->new(twig_handlers=>{
					  'scan[@msLevel="1"]'=>sub {twigMzxml_addPMFSpectrum($this, $_[0], $_[1])},
					  'scan[@msLevel="2"]'=>sub {twigMzxml_addMSMSSpectrum($this, $_[0], $_[1])},
					  'instrument'=>sub {twigMzxml_setInstrument($this, $_[0], $_[1])},
					  pretty_print=>'indented'
					 }
			 );
  (-r $file) or InSilicoSpectro::Utils::io::croakIt "cannot read [$file]";
  print STDERR "xml parsing [$file]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
  $twig->parsefile($file) or InSilicoSpectro::Utils::io::croakIt "cannot parse [$file]: $!";
  undef $spmsms;
  $is=$this->getNbSpectra();
}

sub twigMzxml_setInstrument{
  my($this, $twig, $el)=@_;
  $this->set('date', sprintf("%4d-%2.2d-%2.2d",localtime->year()+1900, localtime->mon()+1, localtime->mday()));
  $this->set('time',sprintf("%2.2d:%2.2d:%2.2d", localtime->hour(), localtime->min(), localtime->sec()));

  my $h=$el->atts();
  foreach (keys %$h){
    $this->{instrument}{$_}=$h->{$_}
  }
}

sub twigMzxml_addPMFSpectrum{
  my($this, $twig, $el)=@_;
  return if $this->{read}{skip}{pmf};
  my $sp=InSilicoSpectro::Spectra::MSSpectra->new();

  $sp->set('peakDescriptor', $pd_mzint);
  $sp->setSampleInfo('retentionTime', $el->atts->{retentionTime}) if $el->atts->{retentionTime};
  $sp->setSampleInfo('sampleNumber', $is++);

   my $elPeaks=$el->first_child('peaks');
   InSilicoSpectro::Utils::io::croakIt "parsing not yet defined for <peaks precision!=32> tag (".($elPeaks->atts->{precision}).")" if $elPeaks->atts->{precision} ne 32;
   my $tmp=$elPeaks->text;
   my ($moz, $int)=twigMzxml_decodeMzXmlPeaks($tmp);
   my $n=(scalar @$moz)-1;
   for (0..$n){
    push @{$sp->{peaks}}, [$moz->[$_], $int->[$_]];
   }
  $this->addSpectra($sp);
}

sub twigMzxml_addMSMSSpectrum{
  my($this, $twig, $el)=@_;
  return if $this->{read}{skip}{msms};
  unless (defined $spmsms){
    $spmsms=InSilicoSpectro::Spectra::MSMSSpectra->new();
    $spmsms->set('parentPD', $pd_mzintcharge);
    $spmsms->set('fragPD', $pd_mzintcharge);
    $spmsms->setSampleInfo('spectrumType', 'msms');
    $spmsms->setSampleInfo('sampleNumber', $is++);
    $spmsms->setSampleInfo('instrument', 'n/a');
    $spmsms->setSampleInfo('instrumentID', 'n/a');

    $this->addSpectra($spmsms);
  }
  $this->twigMzxml_readCmpd($twig, $el);
}

sub twigMzxml_readCmpd{
   my($this, $twig, $el)=@_;

   my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new();
   $cmpd->set('parentPD', $spmsms->get('parentPD'));
   $cmpd->set('fragPD', $spmsms->get('fragPD'));
   my $title="scan_num=".$el->atts->{num};
   $title.=";retentionTime=".$el->atts->{retentionTime} if defined $el->atts->{retentionTime};
   $cmpd->set('title', $title);

   my $elprec=$el->first_child('precursorMz');
   my $c=InSilicoSpectro::Spectra::MSSpectra::string2chargemask($elprec->atts->{precursorCharge})
     or $this->get('defaultCharge');
     #or InSilicoSpectro::Utils::io::croakIt "no default charge nor precursor is defined ($cmpd->{title})";
   $cmpd->set('parentData', [$elprec->text, $elprec->atts->{precursorIntensity}, $c]);

   my $elPeaks=$el->first_child('peaks');
   InSilicoSpectro::Utils::io::croakIt "parsing not yet defined for <peaks precision!=32> tag (".($elPeaks->atts->{precision}).")" if $elPeaks->atts->{precision} ne 32;
   my $tmp=$elPeaks->text;
   my ($moz, $int)=twigMzxml_decodeMzXmlPeaks($tmp);
   my $n=(scalar @$moz)-1;
   for (0..$n){
    $cmpd->addOnePeak([$moz->[$_], $int->[$_]]);
   }

   $spmsms->addCompound($cmpd);
#   push @{$spmsms->{compounds}}, $cmpd;
}

sub twigMzxml_decodeMzXmlPeaks{
  my $l=shift;

  my (@m, @i);
  my $isMz=1;

  my $o=decode_base64($l);
  my @hostOrder32 = unpack ("N*", $o);


  foreach (@hostOrder32){
    if($isMz){
      push @m, unpack("f", pack ("I", $_));
    }else{
      push @i, unpack("f", pack ("I", $_));
    }
    $isMz=1-$isMz;
  }
  return (\@m, \@i);
}

########## EOMzxml

######### mzData

my $spmsms;
my $pd_mzint=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity");
my $pd_mzintcharge=InSilicoSpectro::Spectra::PhenyxPeakDescriptor->new("moz intensity chargemask");
my $is=0;

sub readMzData{
  my ($this, $file)=@_;
  $file=$this->{source} unless defined $file;

  my $twig=XML::Twig->new(twig_handlers=>{
					  'spectrum'=>sub {twigMzdata_addSpectrum($this, $_[0], $_[1])},
					  'description'=>sub {twigMzdata_setDescription($this, $_[0], $_[1])},
					  pretty_print=>'indented'
					 }
			 );
  print STDERR "xml parsing [$file]\n" if $InSilicoSpectro::Utils::io::VERBOSE;
  $twig->parsefile($file) or InSilicoSpectro::Utils::io::croakIt "cannot parse [$file]: $!";
  undef $spmsms;
  $is=0;

}


sub twigMzdata_setDescription{
  my($this, $twig, $el)=@_;
  my @a=$el->get_xpath('admin/sampleName');
  $this->set('title', $a[0]->text);
  $this->set('date', sprintf("%4d-%2.2d-%2.2d",localtime->year()+1900, localtime->mon()+1, localtime->mday()));
  $this->set('time',sprintf("%2.2d:%2.2d:%2.2d", localtime->hour(), localtime->min(), localtime->sec()));

  @a=$el->get_xpath('instrument/instrumentName');
  $this->{instrument}{name}=$a[0]->text;
}

sub twigMzdata_addSpectrum{
  my($this, $twig, $el)=@_;
  my $path='acqDesc/acqSettings/acqInstrument';
  my @a=$el->get_xpath($path);
  unless (@a){
    $path=~s/\bacq/spectrum/g;
    @a=$el->get_xpath($path);
  }
  my $msLevel=$a[0]->atts->{msLevel} or warn "no msLevel defined...\n";
  if($msLevel==1){
    $this->twigMzdata_addPMFSpectrum($twig, $el);
  }elsif($msLevel==2){
    $this->twigMzdata_addMSMSSpectrum($twig, $el);
  }else{
    die __PACKAGE__."(".__LINE__."): no add spectrum sub for msLevel=[$msLevel]";
  }
}

sub twigMzdata_addPMFSpectrum{
  my($this, $twig, $el)=@_;
  return if $this->{read}{skip}{pmf};

  warn "warning: twigMzdata_addPMFSpectrum not defined";
#  my $sp=InSilicoSpectro::Spectra::MSSpectra->new();

#  $sp->set('peakDescriptor', $pd_mzint);
#  $sp->setSampleInfo('sampleNumber', $is++);

#   my $elPeaks=$el->first_child('peaks');
#   croak __PACKAGE__."(".__LINE__."): parsing not yet defined for <peaks precision!=32> tag (".($elPeaks->atts->{precision}).")" if $elPeaks->atts->{precision} ne 32;
#   my $tmp=$elPeaks->text;
#   my ($moz, $int)=twigMzxml_decodeMzDataPeaks($tmp);
#   my $n=(scalar @$moz)-1;
#   for (0..$n){
#    push @{$sp->{peaks}}, [$moz->[$_], $int->[$_]];
#   }
#  $this->addSpectra($sp);
}


sub twigMzdata_addMSMSSpectrum{
  my($this, $twig, $el)=@_;
  return if $this->{read}{skip}{msms};
  unless (defined $spmsms){
    $spmsms=InSilicoSpectro::Spectra::MSMSSpectra->new();
    $spmsms->set('parentPD', $pd_mzintcharge);
    $spmsms->set('fragPD', $pd_mzintcharge);
    $spmsms->setSampleInfo('spectrumType', 'msms');
    $spmsms->setSampleInfo('sampleNumber', $is++);
    $spmsms->setSampleInfo('instrument', 'n/a');
    $spmsms->setSampleInfo('instrumentID', 'n/a');

    $this->addSpectra($spmsms);
  }
  $this->twigMzdata_readCmpd($twig, $el);
}

sub twigMzdata_readCmpd{
   my($this, $twig, $el)=@_;

   my $cmpd=InSilicoSpectro::Spectra::MSMSCmpd->new();
   $cmpd->set('parentPD', $spmsms->get('parentPD'));
   $cmpd->set('fragPD', $spmsms->get('fragPD'));

   my $title="spectrum_id=".$el->atts->{id};
   $title.=";retentionTime=".$el->atts->{retentionTime} if defined $el->atts->{retentionTime};
   $cmpd->set('title', $title);

   return unless $el->get_xpath('spectrumDesc/spectrumSettings/spectrumInstrument[@msLevel="2"');

   my $xpath='spectrumDesc/precursorList/precursor[@msLevel="1"]/ionSelection/cvParam';
   my @a=$el->get_xpath($xpath);
#   unless (@a){
#     $xpath=~s/\bacq/spectrum/g;
#     @a=$el->get_xpath($xpath);
#   }
   @a or return;#InSilicoSpectro::Utils::io::croakIt "cannot find mz node with xpath [$xpath] (s/\bacq/spectrum/g) for msms spectrum [$title] line=".$twig->current_line." col=".$twig->current_column;
   my %h=(
	 );
   foreach (@a){
     if($_->atts->{name}=~/^charge$/i){
       push @{$h{$_->atts->{name}}},$_->atts->{value}
     }else{
       $h{$_->atts->{name}}=$_->atts->{value};
     }
   }

   my $cs=(defined $h{charge})?(join ',', @{$h{charge}}):undef;
   my $c=InSilicoSpectro::Spectra::MSSpectra::string2chargemask($cs)
     or $this->get('defaultCharge');
       #or InSilicoSpectro::Utils::io::croakIt "no default charge nor precursor is defined ($cmpd->{title})";

   $cmpd->set('parentData', [$h{moz}||$h{mz}||$h{MassToChargeRatio}, $h{intensity}||1, $c]);


   @a=$el->get_xpath('mzArrayBinary/data');
   my $e=$a[0];
   InSilicoSpectro::Utils::io::croakIt "parsing not yet defined for <peaks precision!=32> tag (".($e->atts->{precision}).")" if $e->atts->{precision} ne 32;
   InSilicoSpectro::Utils::io::croakIt "parsing not yet defined for <peaks endian!=\"little\"> tag (".($e->atts->{endian}).")" if $e->atts->{endian} ne "little";
   my $o=decode_base64($e->text);
   my @moz=unpack ("f*", $o);

   @a=$el->get_xpath('intenArrayBinary/data');
   my $e=$a[0];
   InSilicoSpectro::Utils::io::croakIt "parsing not yet defined for <peaks precision!=32> tag (".($e->atts->{precision}).")" if $e->atts->{precision} ne 32;
   InSilicoSpectro::Utils::io::croakIt "parsing not yet defined for <peaks endian!=\"little\"> tag (".($e->atts->{endian}).")" if $e->atts->{endian} ne "little";
   my $o=decode_base64($e->text);
   my @int=unpack ("f*", $o);

   for (0..$#moz){
     $cmpd->addOnePeak([$moz[$_], $int[$_]]);
   }

   $spmsms->addCompound($cmpd);
}


######### eo mzData


use SelectSaver;
#sub writeIDJ{
#  my ($this, $format, $out)=@_;

#  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD($out) or die "cannot open [$out]: $!")) if defined $out;
#  foreach($this->{spectra}){
#    next unless defined $_;
#    $_->write($format);
#  }
#}

#---------------------------- writers

sub write{
  my ($this, $format, $out)=@_;
  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD($out) or die "cannot open [$out]: $!")) if defined $out;

  InSilicoSpectro::Utils::io::croakIt "MSRun::".__LINE__.": no write format for [$format]" unless defined $handlers{$format}{write};
  $handlers{$format}{write}->($this);

}

sub writeIDJ{
  my ($this, $out)=@_;

  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD($out) or die "cannot open [$out]: $!")) if defined $out;

print "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
<idj:IdentificationJob xmlns:idj=\"http://www.phenyx-ms.com/namespaces/IdentificationJob.html\">
  <idj:JobId>".($this->get('jobId'))."</idj:JobId>
  <idj:header>
    <idj:contents workflowId=\"n/a\" proteinSize=\"n/a\" priority=\"n/a\" request=\"n/a\"/>
    <idj:date>".($this->get('date'))."</idj:date>
    <idj:time>".($this->get('time'))."</idj:time>
  </idj:header>
  <anl:AnalysisList xmlns:anl=\"http://www.phenyx-ms.com/namespaces/AnalysisList.html\">
";
  $this->writePLE("    ");
print "  </anl:AnalysisList>
</idj:IdentificationJob>
";
}


sub writePLE{
  my ($this, $shift, $out)=@_;
  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD($out) or die "cannot open [$out]: $!")) if defined $out;
#  print STDERR "# spectra= $#spectra\n";
  foreach(@{$this->get('spectra')}){
    next unless defined $_;
    $_->writePLE($shift);
  }
}


sub writeMGF{
  my ($this, $out)=@_;
  my $fdOut=(new SelectSaver(InSilicoSpectro::Utils::io->getFD($out) or die "cannot open [$out]: $!")) if defined $out;
  print "COM=$this->{title}\n";
  if(defined $this->{defaultCharge}){
    print "CHARGE=".InSilicoSpectro::Spectra::MSSpectra::charge2mgfStr((InSilicoSpectro::Spectra::MSSpectra::chargemask2string($this->{defaultCharge})))."\n";;
  }
  print"\n";
  foreach(@{$this->get('spectra')}){
    next unless defined $_;
    $_->writeMGF();
  }
}

# -------------------------------  getters/setters
sub set{
  my ($this, $name, $val)=@_;

  $this->{$name}=$val;
}

=head3 get($name)

=cut

sub get{
  my ($this, $name)=@_;
  return $this->{$name};
}

# -------------------------------   misc

return 1;

