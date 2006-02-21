use strict;

package InSilicoSpectro::Spectra::MSMSCmpd;
use Carp;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK,);
@ISA=qw (Exporter MSSpectra);
@EXPORT=qw();
@EXPORT_OK=qw();

=head1 NAME

InSilicoSpectro::Spectra::MSMSCmpd

=head1 DESCRIPTION

General framework for ms/ms compound (fragmenetaion spectra)

=head1 FUNCTION

=head1 METHODS

=head2 $cmpd->title2acquTime

Try to deduce acquisition from the title (and @title2acquTime_regexes) if it was not defined

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

use InSilicoSpectro::Utils::io;
use InSilicoSpectro::Spectra::PhenyxPeakDescriptor;

our %title2acquTime_regexes=(
			     #Cmpd 11, +MSn(786.25) 16.0 min
			     bruker_classic=>{qr=>qr/\b([\d\.]+)\s*min/i,
unit=>'min',
					     },
			     #Elution from: 24.55 to 24.59   period: 0   experiment: 2 cycles:  2  (Charge not auto determined)(*)
			     qtof_1=>{unit=>'min',
				      qr=>qr/\bElution from:\s*([\d\.]+)/i,
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
#--------------- PeakDescriptor


#--------------- parent Data


=head2 parent data

All the data is stroed in arrays, the peakdescriptors (for parent and fragment) are responsible for stating what is the info stroed in each fields;

All the data (peak data) associated with the parent ion

=head3 setParentData(\@vals | ($index, $val))

=cut

sub setParentData{
  my ($this, $v1, $v2)=@_;
  if((ref $v1) eq 'ARRAY'){
    $this->{parentData}=$v1;
  }else{
    $this->{parentData}[$v1]=$v2;
  }
}

=head3 getParentData (?$i)

if $i is defined, returns argument index $i. If not, it returns the array with all the values;

=cut

sub getParentData{
  my ($this, $i)=@_;
  return (defined $i)?$this->{parentData}[$i]:$this->{parentData};
}

#--------------- cmpd data

=head2 Peaks

=head3 addPeaks(\@peakList)

add a list of peaks

=cut


sub addPeaks{
  my ($this, $pl)=@_;
  foreach(@$pl){
    $this->addOnePeak($_);
  }
}

sub addOnePeak{
  my ($this, $p)=@_;
  push @{$this->{fragments}}, $p;
}

#--------------- getters /setters

=head2 setters/getters

=head3 set($name, $val)

=cut

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

# -------------------------------- data sherlocking
sub title2acquTime{
  my $cmpd=shift;
  return if $cmpd->{acquTime};
  my $title=$cmpd->{title};
  return unless $title;
  foreach my $cvt (values %title2acquTime_regexes){
    if($title=~/$cvt->{qr}/){
      my $et=$1;
      $et*=60 if $cvt->{unit} eq 'min';
      $cmpd->{acquTime}=$et;
      return;
    }
  }

}
# -------------------------------- I/O
#the peakdescriptor
sub readTwigEl{
  my ($this, $el, $pdPar, $pdFrag)=@_;
  $this->set('parentPD', $pdPar);
  $this->set('fragPD', $pdFrag);
  $this->set('title', $el->first_child('ple:PeptideDescr')->text);
  my @d=split /\s+/, $el->first_child('ple:ParentMass')->text;
  $this->set('parentData', \@d);
  my $tmp=$el->first_child('ple:peaks')->text;
  foreach(split /\n/, $tmp){
    next unless /\S/;
    my @p=split;
    $this->addOnePeak(\@p);
  }
}

sub writePLE{
  my ($this, $shift, $transformCharge)=@_;

  return unless ($this->get('fragments') && scalar @{$this->get('fragments')}>1);

  print "$shift<ple:peptide key=\"$this->{key}\" xmlns:ple=\"http://www.phenyx-ms.com/namespaces/PeakListExport.html\">
$shift  <ple:PeptideDescr>".$this->get('title')."</ple:PeptideDescr>
$shift  <ple:acquTime>".$this->get('acquTime')."</ple:acquTime>
$shift  <ple:ParentMass><![CDATA[".$this->get('parentPD')->sprintData($this->getParentData(), $transformCharge)."]]></ple:ParentMass>
$shift  <ple:peaks><![CDATA[\n";
  foreach (@{$this->get('fragments')}){
    print $this->get('fragPD')->sprintData($_, $transformCharge)."\n";
  }
  print "]]></ple:peaks>\n";
  print "$shift</ple:peptide>\n";
}

sub writeMGF{
  my ($this, $transformCharge)=@_;

my $icharge=$this->get('parentPD')->getFieldIndex('charge');
my $ichargemask=$this->get('parentPD')->getFieldIndex('chargemask');
  print "BEGIN IONS
TITLE=".$this->get('title')."
PEPMASS=".$this->get('parentPD')->sprintData($this->getParentData(), $transformCharge)."\n";
  if(defined $icharge){
    my $c=$this->getParentData()->[$icharge];
    if ($c){
      $c=InSilicoSpectro::Spectra::MSSpectra::charge2mgfStr($c);
      print "CHARGE=$c\n";
    }
  }elsif(defined $ichargemask){
    my $c=(InSilicoSpectro::Spectra::MSSpectra::chargemask2string($this->getParentData()->[$ichargemask]));
    if ($c){
      $c=InSilicoSpectro::Spectra::MSSpectra::charge2mgfStr($c);
      print "CHARGE=$c\n";
    }
  }
  foreach (@{$this->get('fragments')}){
    print "".($this->get('fragPD')->sprintData($_, $transformCharge))."\n";
  }
  print "END IONS\n\n";
}

# -------------------------------   misc
return 1;
 
