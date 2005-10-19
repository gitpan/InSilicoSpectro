=head1 NAME

InSilicoSpectro - InSilico Mass Spectrometry toolkit

=head1 DESCRIPTION

=head1 INSTALL

=head1 FUNCTIONS

=head3 saveInSilicoDef([$out])

Saves all registred definitions into $out (eg insilicodef.xml)

=head3 getInSilicoDefFile()

returns the default insilicodeffile, from environament variable named by $InSilicoSpectro::DEF_FILENAME_ENV (default is $INSILICOSPECTRO_DEFFILE)

=head1 SEE ALSO

InSilicoSpectro::InSilico::CleavEnzyme, InSilicoSpectro::InSilico::ModRes, InSilicoSpectro::Spectra, InSilicoSpectro::Utils

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

use strict;

package InSilicoSpectro;
require Exporter;
use Carp;

use InSilicoSpectro::InSilico::CleavEnzyme;
use InSilicoSpectro::InSilico::ModRes;

our (@ISA, @EXPORT, @EXPORT_OK, $VERSION);
@ISA = qw(Exporter);

@EXPORT = qw($VERSION &saveInSilicoDef &init &getInSilicoDefFile $DEF_FILENAME_ENV);
@EXPORT_OK = ();
$VERSION = "1.2.4";

our $DEF_FILENAME_ENV='INSILICOSPECTRO_DEFFILE';

sub saveInSilicoDef{
  my $out=shift;
  $out=">$out" if ((defined $out) and not $out=~/^>/);
  my $saver=(defined $out)?(new SelectSaver(InSilicoSpectro::Utils::io->getFD($out) or die "cannot open [$out]: $!")):\*STDOUT;
  print <<EOT;
<inSilicoDefinitions>
  <elements/>
  <aminoAcids/>
  <codons/>
  <cleavEnzymes>
EOT
  foreach (InSilicoSpectro::InSilico::CleavEnzyme::getList()){
    $_->getXMLTwigElt->print();
    print "\n";
  }
  print <<EOT;
  </cleavEnzymes>
  <fragTypeDescriptions/>
  <modRes>
EOT
  foreach (InSilicoSpectro::InSilico::ModRes::getList()){
    $_->getXMLTwigElt->print();
    print "\n";
  }
  print <<EOT;
  </modRes>
</inSilicoDefinitions>
EOT
}

sub init{
  my @tmp=@_;
  push(@tmp, getInSilicoDefFile()) if ((not @tmp) and getInSilicoDefFile());

  unless(@tmp){
    print STDERR "no default found, opening config file from Phenyx::Config::GlobalParam\n" if $InSilicoSpectro::Utils::io::VERBOSE;
    require Phenyx::Config::GlobalParam;
    Phenyx::Config::GlobalParam::readParam(undef, 1);
    require Phenyx::Manage::User;
    my $tmp=Phenyx::Manage::User->new(name=>'default')->getFile('insilicodef.xml');
    push @tmp, $tmp;
  }
  @tmp or croak "must provide at least one  file argument";

  
  InSilicoSpectro::InSilico::ModRes::init(@tmp);
  InSilicoSpectro::InSilico::CleavEnzyme::init(@tmp);
  InSilicoSpectro::InSilico::MassCalculator::init(@tmp);

}

sub getInSilicoDefFile{
  return $ENV{$DEF_FILENAME_ENV};
}

1;
