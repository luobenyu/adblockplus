#!/usr/bin/perl

use strict;
use warnings;
use lib qw(../buildtools);
use Packager;

my %params = ();

my $output_file = shift @ARGV || "adblockplus.zip";
if (@ARGV && $ARGV[0] =~ /^\+/)
{
  $params{devbuild} = $ARGV[0];
  shift @ARGV;
}

my $pkg = Packager->new(\%params);
$pkg->readVersion('../version');

my $KMELEON_SRC = 'c:/kmeleon_src';
my $GECKO_DIR = 'c:/kmeleon_src/mozilla/mozilla/dist';
my $CCFLAGS = '-O1 -W3 -LD -MT -DXP_WIN -Zc:wchar_t-';
my $LDFLAGS = '-DLL -NODEFAULTLIB -NOLOGO -PDB:../adblockplus.pdb';
my @INCLUDE_DIRS = ("$KMELEON_SRC/src", map {"$GECKO_DIR/include/$_"} qw(caps content dom gfx imglib2 js layout necko nspr pref string webbrwsr widget xpcom xpconnect));
my @LIB_DIRS = ("$GECKO_DIR/lib");
my @SOURCE_FILES = <*.cpp>;
my @LIBS = qw(libcmt.lib kernel32.lib user32.lib gdi32.lib comctl32.lib nspr4.lib plds4.lib plc4.lib xpcom.lib xpcomglue_s.lib embed_base_s.lib unicharutil_external_s.lib js3250.lib);

$params{locales} = \@ARGV if @ARGV;
$params{locales} = ["en-US"] unless exists $params{locales};

$CCFLAGS .= " -DABP_VERSION=" . escapeMacro($params{version});
$CCFLAGS .= " -DABP_LANGUAGE=" . escapeMacro($params{locales}[0]);

my $includes = join(' ', map {"-I$_"} @INCLUDE_DIRS);
my $libs = join(' ', map {"-LIBPATH:$_"} @LIB_DIRS);

$pkg->rm_rec('tmp');
mkdir('tmp', 0755) or die "Failed to create directory tmp: $!";

$pkg->cp($_, "tmp/$_") foreach @SOURCE_FILES;
$pkg->cp('adblockplus.h', 'tmp/adblockplus.h');

chdir('tmp');
system("cl $CCFLAGS $includes @SOURCE_FILES @LIBS -Feadblockplus.dll -link $LDFLAGS $libs") && exit;
system("mv -f adblockplus.dll ..") && exit;
chdir('..');

chdir('../chrome');
$pkg->makeJAR('adblockplus.jar', 'content', 'skin', 'locale', '-/tests', '-/mochitest', '-/.incomplete');
chdir('../kmeleon');

$pkg->rm_rec('tmp');
mkdir('tmp', 0755) or die "Failed to create directory tmp: $!";

$pkg->cp_rec("../defaults", "tmp/defaults");

mkdir('tmp/chrome', 0755) or die "Failed to create directory tmp/chrome: $!";
system("mv -f ../chrome/adblockplus.jar tmp/chrome/adblockplus.jar");

{
  local $/;

  open(FILE, "../chrome.manifest");
  my $manifest = <FILE>;
  close(FILE);

  $manifest =~ s/jar:chrome\//jar:/g;
  $manifest =~ s/(\s)modules\//$1..\/modules\/adblockplus\//g;
  $manifest =~ s/(\s)(defaults\/)/$1..\/$2/g;

  open(FILE, ">tmp/adblockplus.manifest");
  print FILE $manifest;
  close(FILE);
}
$pkg->cp("tmp/adblockplus.manifest", "tmp/chrome/adblockplus.manifest");

system("mv -f tmp/defaults/preferences tmp/defaults/pref") && exit;
$pkg->cp("adblockplus_extra.js", "tmp/defaults/pref/adblockplus_extra.js");

mkdir("tmp/kplugins", 0755) or die "Failed to created directory tmp/kplugins: $!";
system("mv -f adblockplus.dll tmp/kplugins/adblockplus.dll");

mkdir("tmp/macros", 0755) or die "Failed to created directory tmp/macros: $!";
$pkg->cp("adblockplus.kmm", "tmp/macros/adblockplus.kmm");

mkdir("tmp/modules", 0755) or die "Failed to created directory tmp/modules: $!";
$pkg->cp_rec("../modules", "tmp/modules/adblockplus");
$pkg->cp("AppIntegrationKMeleon.jsm", "tmp/modules/adblockplus/AppIntegrationKMeleon.jsm");

chdir('tmp');

unlink("../$output_file");
system('zip', '-rX9', "../$output_file", qw(kplugins chrome defaults macros modules));

chdir('..');
$pkg->rm_rec('tmp');

sub escapeMacro
{
  my $value = shift;

  $value =~ s/([\\"])/\\$1/g;
  $value = '"'.$value.'"';
  $value =~ s/([\\"])/\\$1/g;

  return $value;
}
