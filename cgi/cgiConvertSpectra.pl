#!/usr/bin/env perl
use strict;
use Carp;
use Pod::Usage;

=head1 NAME

cgiConvertSpectra.pl


=head1 DESCRIPTION

Converts MS and MS/MS peak lists from/to various formats. See convertSpectra.pl documentation for more details.

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


$|=1;		        #  flush immediately;

BEGIN{
  push @INC, '../../lib';
  eval{
   require DefEnv;
   DefEnv::read();
  };
}

END{
}

my $isCGI;
use CGI qw(:standard);
if($isCGI){
  use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
  warningsToBrowser(1);
}

BEGIN{
  $isCGI=$ENV{GATEWAY_INTERFACE}=~/CGI/;
  sub carp_error{
    my $msg=shift;
    if ($isCGI){
      my $q=new CGI;
      error($q, $msg);
    }else{
      print STDERR $msg;
    }
  }
  CGI::Carp::set_message(\&carp_error) if $isCGI;

  sub error(){
    my($q, $msg)=@_;
    #  $q->header;
    print $q->start_html(-title=>"$0 - ms/ms peaklist converter",
			 -author=>'alexandre.masselot@genebio.com',
			 -BGCOLOR=>'white');
    print "<center><h1>$0</h1></center>\n";
    print  "<pre>$msg</pre>\n";
    $q->end_html;
    exit;
  }
}

use InSilicoSpectro::Spectra::MSRun;
use InSilicoSpectro::Spectra::MSSpectra;
use InSilicoSpectro::Utils::io;
use File::Basename;
use CGI qw(:standard);

my $query = new CGI;

if($query->param('doc')){
  print $query->header;
  while(<DATA>){
    print $_;
  }
  exit(0);
}

unless($query->param('inputfile')){
  my %cookies=$query->cookie('cgiConvertSpectra.pl');
  my $inputformat=$cookies{inputformat};
  my $outputformat=$cookies{outputformat};
  my $defaultcharge=$cookies{defaultcharge};

  my $script=basename $0;
  print $query->header;
  print $query->start_html(-title=>"$script - ms/ms peaklist converter",
			   -author=>'alexandre.masselot@genebio.com'
			  );

  print <<EOT;
<body>
  <center>
    <h1>$script</h1>
    <h3>ms/ms peaklist converter (<a href="$script?doc=1">?</a>)</h3>
  </center>
  <form name='spetraconvertor' method='post' enctype='multipart/form-data'>
  <table border=1 cellspacing=0>
    <tr>
      <td>Input file (<a href="$script?doc=1#inputfile">?</a>)</td>
      <td><input type='file' name='inputfile'></td>
    </tr>
    <tr>
      <td>Input format (<a href="$script?doc=1#inputformat">?</a>)</td>
      <td><select name='inputformat'>
EOT
  foreach (InSilicoSpectro::Spectra::MSMSSpectra::getReadFmtList()){
    print "         <option value='$_'".(($_ eq $inputformat)?' selected="selected"':'').">".InSilicoSpectro::Spectra::MSMSSpectra::getFmtDescr($_)."</option>\n";
  }
  foreach (InSilicoSpectro::Spectra::MSRun::getReadFmtList()){
    print "         <option value='$_'".(($_ eq $inputformat)?' selected="selected"':'').">".InSilicoSpectro::Spectra::MSRun::getFmtDescr($_)."</option>\n";
  }
  print <<EOT;
        </select>
      </td>
    </tr>
    <tr>
      <td>Default charge (<a href="$script?doc=1#defaultcharge">?</a>)</td>
      <td><select name='defaultcharge'>
EOT
  foreach (('1+', '2+', '3+', '2+,3+', '4+')){
    print "         <option value='$_'".(($_ eq $defaultcharge)?' selected="selected"':'').">$_</option>\n";
  }
  print <<EOT;
        </select>
      </td>
    </tr>
    <tr>
      <td>Output format (<a href="$script?doc=1#outputformat">?</a>)</td>
      <td><select name='outputformat'>
EOT
  foreach (InSilicoSpectro::Spectra::MSMSSpectra::getWriteFmtList()){
    print "         <option value='$_'".(($_ eq $outputformat)?' selected="selected"':'').">".InSilicoSpectro::Spectra::MSMSSpectra::getFmtDescr($_)."</option>\n";
  }
  print <<EOT;
        </select>
      </td>
    </tr>
    <tr>
      <td>Title (<a href="$script?doc=1#title">?</a>)</td>
      <td><input type='textfield' name='title' size=50/></td>
    </tr>
  </table>
  <input type="submit" value="convert"/>
  </form>
EOT
  print $query->end_html;
  exit(0);
}


my $fileIn=$query->param('inputfile')||die "must provide filein parameter";
my $inputFormat=$query->param('inputformat')||die "must provide input format";
my $outputFormat=$query->param('outputformat')||die "must provide output format";
my $defaultCharge=$query->param('defaultcharge') || die "must provide default parent charge";
my $title=$query->param('title');

my $help=$query->param('help');
pod2usage(-verbose=>2, -exitval=>2) if(defined $help);


my %cookies;
$cookies{inputformat}=$inputFormat;
$cookies{outputformat}=$outputFormat;
$cookies{defaultcharge}=$defaultCharge;

use File::Basename;
use File::Temp qw(tempfile);
#upload
my $ext=".tmp";
$ext=".gz" if ($fileIn=~/.t?gz$/i);
$ext=".zip" if ($fileIn=~/.zip$/i);
my $fhin=upload('inputfile')||die "cannot convert [$fileIn] into filehandle";
my $bn=basename $fileIn;
my ($fhout, $finTmp)=tempfile(UNLINK=>1, SUFFIX=>$ext);
while (<$fhin>){
  print $fhout $_;
}
close $fhin;
close $fhout;

my @fileIn;
if($fileIn =~ /\.(tgz|tar\.gz|tar)$/i){
  use Archive::Tar;
  my $tar=Archive::Tar->new;
  $tar->read($finTmp,$fileIn =~ /\.(tgz|tar\.gz)$/i);
  foreach ($tar->list_files()){
    my ($fdtmp, $tmp)=tempfile(SUFFIX=>$inputFormat, UNLINK=>1);
    $tar->extract_file($_, $tmp);
    push @fileIn, {format=>$inputFormat, file=>$tmp, origFile=>basename($_)};
    close $fdtmp;
  }
}else{
  if($fileIn=~/\.gz$/i){
    my (undef , $ftmp)=tempfile(UNLINK=>1);
    print STDERR "fin=$finTmp\n";
    InSilicoSpectro::Utils::io::uncompressFile($finTmp, {remove=>0, dest=>$ftmp});
    $fileIn=~s/\.gz$//i;
    $fileIn=~s/\.tgz$/.tar/i;
  }
  if($fileIn=~s/\.zip$//i){
    die ".zip not yet implemented";
  }
  @fileIn=({file=>$finTmp, origFile=>basename($fileIn)});
}


my $run=InSilicoSpectro::Spectra::MSRun->new();
$run->set('defaultCharge', InSilicoSpectro::Spectra::MSSpectra::string2chargemask($defaultCharge));
$run->set('title', $title);
$run->set('format', $inputFormat);
$run->set('origFile', basename $fileIn);
$run->set('source', $finTmp);

my $is=0;
foreach (@fileIn){
  unless (defined $InSilicoSpectro::Spectra::MSRun::handlers{$inputFormat}{read}) {
    my %h;
    foreach (keys %$run) {
      $h{$_}=$run->{$_};
    }
    my $sp=InSilicoSpectro::Spectra::MSSpectra->new(%h);
    $sp->{source}=$_->{file};
    $sp->{origFile}=$_->{origFile};
    $sp->{title}="$title";
    $run->addSpectra($sp);
    $sp->open();
  } else {
    die "not possible to set multiple file in with format [$inputFormat]" if $#fileIn>0;
    $InSilicoSpectro::Spectra::MSRun::handlers{$inputFormat}{read}->($run);
  }
}

my $dest=basename $fileIn;
$dest=~s/\.$inputFormat//i;
$dest.=".$outputFormat";
my $cookie=cookie(-name=>'cgiConvertSpectra.pl',
		  -value=>\%cookies,
		  -expires=>'+100d'
		 );

print $query->header(-type=>'text/plain',
		     -cookie=>$cookie,
		     -attachment=>$dest,
		    );
$run->write($outputFormat, \*STDOUT);


__DATA__
<html>
  <head>
    <title>cgiConvertSpectra.pl - ms/ms peaklist converter</title>
  </head>
  <body>
    <center>
      <h1>cgiConvertSpectra</h1>
      <h3>ms/ms peaklist converter</h3>
    </center>
  <a name="goal"/><h3>Goal</h3>
  This script converts peak list in various formats to other proposed formats.
  <p/>
  If two fragmentation spectra have the same fragment masses, and compatible precursor data, they will be merged automatically and the precursor assigned a multi-charge, e.g. <i>2+ AND 3+</i>.
  <p/>Selections will be stored on the browser via a set of cookies.
  <a name="inputfile"/><h3>Inut File</h3>
  Peak list data, provided in the input format. It is possible to provide compressed <i>.gz</i> or in <i>.tar</i> (or even <i>.tar.gz</i> or <i>.tgz</i>), <i>.zip</i> files.
  <a name="inputformat"/><h3>Input format</h3>
  The list of formats with available <i>read</i> handlers.
  <a name="defaultcharge"/><h3>Default charge</h3>
  In case no default parent charge is given in the input file, the selected charge(s) will be applied to precursors.
  <a name="outputformat"/><h3>Ouput format</h3>
  The list of formats with available <i>write</i> handlers.
  <a name="title"/><h3>Title</h3>
  Some formats allow for a title (ex: the <i>COM</i> line in an mgf file).
  <body>
</html>
