#!/usr/bin/perl

our $dbug = 0;
my ($red,$nc) = ('[31m','[0m');

my $HOME = $ENV{HOME} || '/home/'.$ENV{USERNAME};

#understand variable=value on the command line...
eval "\$$1='$2'"while $ARGV[0] =~ /^(\w+)=(.*)/ && shift;

printf "debug: %s\n",$dbug;

# load htm file and replace include tag with its src content...
my $file = shift;
my ($fpath,$bname,$ext) = &bname($file);

# -------------------------------------------------
# get the file names
my $target;
if ($ARGV[0]) {
  $target = $ARGV[0];
  ($fpath,$bname,undef) = &bname($target);
} else {
  $target = $file; $target =~ s/\.$ext/.html/;
}
# -------------------------------------------------
# extract front matter

# -------------------------------------------------
my $htmfile;
if ($ext ne 'htmx') {
   # no .htmx file use layout.htmx file
   $htmfile = $file;
   if (! -e "$bname.htmx" && -e 'layout.htmx') {
      $file = 'layout.htmx';
   } else {
      $file = $HOME.'/GITrepo/Layout/layout.htmx';
   }

} elsif (! -e $file && -e 'layout.htmx') {
   $file = 'layout.htmx';
   $htmfile = "$bname.htmp";
} else {
   $htmfile = "$bname.htmp";
   print "htmfile : $htmfile\n";
}
my $cssfile;
if (-e "$bname.css") {
  $cssfile = "$bname.css";
  print "cssfile : $cssfile\n";
} elsif (-e 'style.css') {
  $cssfile = "style.css";
} else {
  $cssfile = "http://cloudflare-ipfs.com/ipfs/Qmd1nQMoCf32jCEjp3woEBuvAVNdTN1f7DBggyzDkefMS9";
  $cssfile = "http://gateway.ipfs.io/ipns/QmQBQfNEDm6nC8j3kCWquENbKJTJ37Mw998NZ68PLvayjx/style.css";
  $cssfile = "http://yoogle.com:8080/ipns/QmQBQfNEDm6nC8j3kCWquENbKJTJ37Mw998NZ68PLvayjx/style.css";
  $cssfile = "http://cloudflare-ipfs.com/ipns/QmQBQfNEDm6nC8j3kCWquENbKJTJ37Mw998NZ68PLvayjx/style.css";
  $cssfile = 'https://cdn.jsdelivr.net/gh/iglake/cssjs@4b65b3d/css/style.css';
  $cssfile = 'https://cdn.jsdelivr.net/gh/iglake/cssjs@master/css/style.css';
}


my $c = 0;
# ----------------------------------------
# 1) read file
local *S; open S,'<',$file;
local $/ = undef; my $buf = <S>; close S;
$buf =~ s/\{\{file\.ht[em]\}\}/$htmfile/g;
$buf =~ s/\{\{file\.css\}\}/$cssfile/;
# ----------------------------------------
# 2) Environment substitution & includes
foreach my $var (reverse sort keys %ENV) {
   next if $var eq '_';
   if ($buf =~ m/\$\{?$var\}?/) {
      my $value = $ENV{$var};
      print "s|\\\$$var|$value|g;\n";
      $c += $buf =~ s/\$$var/$value/g;
      $c += $buf =~ s/\$\{$var\}/$value/g;
   }
}
#printf "c:%d (env)\n",$c;
# 2b) expand includes :
my $i = &expand($buf);
printf "i:%d\n",$i;
# ----------------------------------------
# 3) redo Environment substitution after includes ...
foreach my $var (reverse sort keys %ENV) {
   next if $var eq '_';
   if ($buf =~ m/\$\{?$var\}?/) {
      my $value = $ENV{$var};
      print "s|\\\$$var|$value|g;\n";
      $c += $buf =~ s/\$$var/$value/g;
      $c += $buf =~ s/\$\{$var\}/$value/g;
   }
}
printf "c:%d (env)\n",$c;
# ----------------------------------------
# 4) class and ids substitution ...
$c += &csssubsti($buf);
printf "c:%d (css)\n",$c;
# ----------------------------------------
# 5) reapply md substitions ... (TITLE etc.)
my $mdfile = "$bname.md";
print "(re)-loading $mdfile\n";
local *MD; open MD,'<',$mdfile;
local $/ = "\n"; my $title = <MD>; chomp($title);
$title =~ s/^%\s+//;
seek(MD,0,0); # rewind !
$/ = undef; my $mdbuf = <MD>;
close MD;
my $yml = &extract_yml($mdbuf);
#YAML::Syck::DumpFile("layout.yml",$yml);

my $mh = &ipfsadd($mdfile);
my $split = substr($mh->{$mdfile},-3,1);
print "SPLIT: $split\n";
$yml->{SPLIT} = $split;

#printf "${red}md:${nc} %s.\n",Dump($yml); exit;
#printf "mdbuf: %s.\n",$mdbuf;

$c += &substi($yml,$buf);
printf "c:%d (md)\n",$c;
# ----------------------------------------

# 6) extract yaml data :
my $local_yml = &extract_yml($buf);
foreach my $key (keys %$local_yml) {
 $yml->{$key} = $local_yml->{$key};
}
use YAML::Syck qw(Dump); printf "yml: %s.\n",Dump($yml) if ($dbug > 3); # DBUG

# ----------------------------------------
# 7) substitude HTML's moustaches ...
$c += &substi($yml,$buf);
printf "c:%d ($file)\n",$c;
# ----------------------------------------
# 8) load yml included file too ...
if (exists $yml->{layout}) {
  my @list = ();
  if (ref $yml->{layout} eq 'ARRAY') {
    push @list, @{$yml->{layout}};
    printf "list: %s.\n",join',',@list if $dbug;
  } else {
    push @list, $yml->{layout};
  }
  foreach my $y (@list) {
     $y =~ s/\{\{([^}]+)\}\}/$yml->{$1}/g; # do subs on list elements too
     if (-e $y) {
        print " loading $y\n";
        local *Y; open Y,'<',$y;
        local $/ = undef; my $ybuf = <Y>; close Y;
        my $local_yml = &extract_yml($ybuf);
        $c += &substi($local_yml,$buf);
        printf "c:%d (${y}'s)\n",$c;
        # propagate fonts & backgrounds up ...
        if (exists $local_yml->{'font-family'}) {
          $yml->{'font-family'} = $local_yml->{'font-family'};
        }
        if (exists $local_yml->{'BGQMs'}) {
          $yml->{'BGQMs'} = $local_yml->{'BGQMs'};
        }
        if (exists $local_yml->{'CBGQMs'}) {
          $yml->{'CBGQMs'} = $local_yml->{'CBGQMs'};
        }
     } else {
       printf " ! -e %s\n",$y; # if $dbug;
     }
  }
}

# DEFAULT SUBSTITUTION ...
#$yml->{WWW} = $HOME . '/odrive/Tommy/public_html'; # <---
$yml->{CHART} = 'http://chart.googleapis.com/chart?cht=qr&choe=UTF-8&chld=H&chs=210&chl';
$yml->{DUCK} = 'http://duckduckgo.com/?q'; # <---
$yml->{SEEKS} = 'https://seeks.hsbp.org/?language=en&engines=google,duckduckgo,qwant,ixquick,startpage&q';
$yml->{SEARX} = 'http://siderus.io/ipns/searx.neocities.org/?q';
$yml->{SEARXES} = 'https://searxes.danwin1210.me/?lg=en-US&search_this';
$yml->{GOO} = 'http://google.com/search?bti=1&q';
$yml->{FBK} = 'https://l.facebook.com/l.php?u';


$yml->{ZGW} = 'http://0.0.0.0:8080';
$yml->{IPGW} = 'http://ipfs.iph.heliohost.org';
$yml->{GCGW} = 'http://ipfs.gc-bank.tk';
$yml->{MLGW} = 'http://.ml';
$yml->{TGGW} = 'http://ipfs.2gether.cf';
$yml->{CFGW} = 'https://cloudflare-ipfs.com';
$yml->{PUBGW} = 'http://gateway.ipfs.io';
$yml->{PGW} = 'https://siderus.io';
$yml->{IPROXY} = 'http://ipns.co';

$yml->{IPH} = 'http://iph.heliohost.org/IPHS';
$yml->{AHE} = 'http://iph.heliohost.org/AHE';
$yml->{HELIO} = 'http://iph.heliohost.org';
$yml->{TOMMY} = 'http://tommy.heliohost.org';

my $mfile =  (-e $htmfile) ? $htmfile : $file;
my $mtime = (lstat($mfile))[9];
my $mh58 = &get_mhash($mfile);
my $ghash = &get_digest('GIT',$mfile);
print "$mfile: gitid=$ghash\n" if $dbug;
my $id7 = substr($ghash,0,7);
my $md6 = &get_digest('MD6',$mfile);
print "$mfile: md6=$md6\n" if $dbug;
my $pn = hex(substr($md6,-4)); # 16-bit
my $build = &word($pn);
$yml->{BNAME} = $bname;
$yml->{VERSION} = sprintf 'v%g',scalar &rev($mtime);
$yml->{'SN#'} = $pn;
$yml->{BUILD} = $build;
$yml->{GITHASH} = $ghash;
$yml->{'V\*BOT'} = sprintf'https://robohash.org/%s?size=113x113',$ghash;
$yml->{MH58} = $mh58;

my $seed = srand(hex($id7));
$yml->{SEED} = $seed;
$yml->{'<3'} = '<span style="color:red;"><3</span>';

# 9) font family substitution :
# pick set of fonts 
if (exists $yml->{'font-family'}) {
  #use YAML::Syck qw(Dump); printf "fonts: %s.\n",Dump($yml->{'font-family'});
  my $fontlist = $yml->{'font-family'};
  foreach my $set (keys %{$fontlist}) {
     my $i = rand(scalar @{$fontlist->{$set}});
     my $font = $fontlist->{$set}[$i];
     #printf "font-%s: %s\n",$set,$font;
     $yml->{"font-$set"} = $font;
  }
}
# Background images
if (exists $yml->{'BGQMs'}) {
  #YAML::Syck::DumpFile('BGQMs.yml',$yml->{'BGQMs'});
  my $list = $yml->{'BGQMs'};
  my $n = scalar @{$list};
  my $i = rand(5);
     $i = int ($^T/60 + $i) % $n;
  my $bg_img = $list->[$i];
  $yml->{"BG-IMG-URL"} = 'http://siderus.io/ipfs/'.$bg_img;
  #$yml->{"BG-IMG-URL"} = '//gateway.ipfs.io/ipfs/'.$bg_img;
  $yml->{"BG-IMG-URL"} = 'http://ipfs.gc-bank.tk/ipfs/'.$bg_img;
  $yml->{"BG-IMG-URL"} = 'https://ipns.co/ipfs/'.$bg_img;
}
if (exists $yml->{'CBGQMs'}) {
  my $list = $yml->{'CBGQMs'};
  my $n = scalar @{$list};
  my $i = rand(5);
     $i = int ($^T/60 + $i) % $n;
  my $bg_img = $list->[$i];
   print "$bg_img <------\n";
  #$yml->{"CBG-IMG-URL"} = '//gateway.ipfs.io/ipfs/'.$bg_img;
  $yml->{"CBG-IMG-URL"} = 'http://ipfs.gc-bank.tk/ipfs/'.$bg_img;
}
$c += &substi($yml,$buf);
printf "c:%d (defaults, fonts & bg)\n",$c;


# 10)  build keys substitution list :
my $keys = &get_keylist();
#foreach (keys %$keys) { $keys->{$_.'ID'} = $keys->{$_}; # keyname alias !  }
$c += &substi($keys,$buf);
printf "c:%d (keys)\n",$c;

# --------------------------------------

my $tics;
if (exists $yml->{AppliedOn}) {
  $tics = &get_tics2($yml->{AppliedOn});
  my ($mm,$dd,$yr4) = split'/',$yml->{AppliedOn};
  print "tmdy: $tics $mm $dd $yr4\n";
  $yml->{MM} = $mm;
  $yml->{DD} = $dd;
} 
# date and time ...
$yml->{TICS} = $tics || $^T;
##     0    1     2    3    4     5     6     7
#y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
my ($mon,$year) = (localtime($yml->{TICS}))[4,5];
my $LMoY = [qw( January February March April May June July August September October November December )];
$yml->{HDATE} = &hdate($yml->{TICS});
$yml->{PREVMONTH} = $LMoY->[($mon+11) % 12];
$yml->{MONTH} = $LMoY->[$mon];
$yml->{YR4} = $year +1900;
$yml->{YR2} = $year % 100;
$yml->{TODAY} = &hdate($^T);
my $letter = &letter($^T);
$yml->{LETTER} = $letter;

my $fortune = `fortune -n 120`;
$yml->{FORTUNE} = $fortune;

# define tittle 
$yml->{TITLE} = $title;
# ---------------------
printf "md: s/{{TICS}}/%s/ ... etc.\n",$yml->{TICS};
$c += &substi($yml,$buf);
printf "c:%d (reapply md)\n",$c;
# --------------------------------------

# 11) add charset ...

if ($buf !~ /charset=/) {
  $buf = '<meta name="utf8" charset="utf-8">'.$buf;
 # $buf = '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'.$buf;
}

my $buf0 = $buf; # branched out for personal use ...

# 12) reverse environment substitution ...
sub by_value { $ENV{$b} cmp $ENV{$a} }
if ($dbug) {
foreach my $var (sort by_value grep !/(?:LVL|MODULE|USER|LOGNAME|PAPER|SESSION|LS_)/, keys %ENV) {
    printf "// %-24s: '%s' -> \$%s\n",$var,$ENV{$var},$var;
}
}
foreach my $var (sort by_value grep !/(?:LVL|MODULE|USER|LOGNAME|PAPER|SESSION|LS_)/, keys %ENV) {
  next unless $var =~ m/^[A-Z][A-Z_]+$/;
  next if $ENV{$var} =~ m/^\d+$/;
  printf "--> %s: %s exists!\n",$var,$ENV{$var} if (exists $yml->{$var});
  next if (exists $yml->{$var});
  my $value = $ENV{$var};
  next if length($value) < 3; 
  next if $value =~ m/[%\$= ]/;
  if ($buf =~ m/$value/) {
    $buf =~ s/$value/\${$var}/g;
    print "s/$value/\${$var}/g\n";;
  }
}

if ($buf =~ m/iggy/) {
    $buf =~ s/iggy/agustin/g;
}

# 13) using local IPFS gateways and personal site version
my $dotip = &get_localip();

$buf0 =~ s{https?://gateway.ipfs.io/} {http://$dotip:8080/}g;
$buf0 =~ s{//gateway.ipfs.io/} {http://0.0.0.0:8080/}g;
$buf0 =~ s{http://dweb.link/} {http://127.0.0.1:8080/}g;
$buf0 =~ s{https?://[^/\.0-9]+/(?=ip[fn]s/(?:[Qm]|z))} {http://0.0.0.0:8080/}g;
#$buf0 =~ s{https?://iph.heliohost.org/(?!ip[fn]s)} {http://0.0.0.0:8088/}g; # negative look-ahead assertion 
$buf0 =~ s{https?://([^\.]+).neocities.org/} {http://0.0.0.0:8088/neocities/site/\1/}g;
printf "... (using personal gateways)\n";


# 14) write file
if ($file eq $target) { # /!\ DANGEROUS 
   print "// ${red}/!\\${nc} CAUTION $file is rename to $file~\n";
   unlink "$file~"; rename $file,"$file~";
}
{ print "// layout: -> $target\n";
local *T; open T,'>',$target;
print T $buf;
close T;
}

# if prevQM,nextQM,topQM
if ($buf =~ m/\{\{prevQM\}\}/) {
  my $mh = &ipfsadd('-w',$target);
  my $prev = $mh->{"$bname.$ext"};
  $buf =~ s,\{\{prevQM\}\},/ipfs/$prev,g;
  # TBD ... choose a better way to chain documents...
}


# personal version
if (0) { local *T; open T,'>',"$bname.local";
print T $buf0;
close T;
}

if (exists $yml->{COPYIN}) {
  $yml->{COPYIN} =~ s/\{\{SPLIT\}\}/$split/i;
  &copy(${mdfile}.'x', $yml->{COPYIN});
  my $mh = &ipfsadd('-w',$yml->{COPYIN});
  # ${mdfile}.'x.log' keep log of ipfs
  printf "// cp -p %sx %s\n",$mdfile,$yml->{COPYIN};
  if (-e 'metadata.yml') {
     &copy('metadata.yml', sprintf'covers/metatata-%s%s.yml',$yml->{SN},$split) ;
  }
} else {
  #printf "DBUG> YML: %s\n",Dump($yml);
}
my $mh = {};
if (exists $yml->{COPYOUT}) { # for ORP
  &copy($target, $yml->{COPYOUT});
  printf "// cp -p %s %s\n",$target,$yml->{COPYOUT};
  printf "// %s\n",$yml->{COPYOUT};
  #printf "// ipfs add -w %s ../201*-*_mgc_resume_en.pdf\n",$yml->{COPYOUT};
  $mh = &ipfsadd('-w',$yml->{COPYOUT},'ThisMonth/2019-09_mgc_resume_en.pdf');
  printf "// http://ipfs.io/ipfs/%s\n",$mh->{wrap};
  local *F;
  open F,'>','ipath.yml';
  printf F "--- # ipath\nIPATH: /ipfs/%s\n",$mh->{wrap};
  printf F "...\n";
  close F;

  # --------------------
  open F,'>>',"$bname.log";
  printf F "#%s%s %s (%s): %s\n",$yml->{SN},$split,$yml->{Company},$yml->{City},$yml->{Position};
  printf F "URL=http://ipfs.io/ipfs/%s\n",$mh->{wrap};
  close F;
  system "echo 136,145p |ed $yml->{COPYOUT} >> candidature.mdx";
  # --------------------
   

  my $buf1 = $buf;
  $buf1 =~ s,\%7B\%7BIPATH\%7D\%7D,/ipfs/$mh->{wrap},g;
  $buf1 =~ s,\{\{IPATH\}\},/ipfs/$mh->{wrap},g;
  local *T; open T,'>',$yml->{COPYOUT};
  print T $buf1;
  close T;

  # pdf generation ...
  my $pdf = $yml->{COPYOUT}; $pdf =~ s/\.html?$/.pdf/;
  my $status = system "pandoc -f html -o $pdf $yml->{COPYOUT};";
  # rtf generation ...
  my $rtf = $yml->{COPYOUT}; $rtf =~ s/\.html?$/.rtf/;
  my $status = system "pandoc -f html -o $rtf $yml->{COPYOUT};";
  $mh = &ipfsadd('-w',$yml->{COPYOUT},'ThisMonth/2019-09_mgc_resume_en.pdf',$pdf,$rtf,'jobpost.htm','ThisMonth/mgc-circle.png'); # do-it again ...
  printf "firefox http://yoogle.com:8080/ipfs/%s\n",$mh->{wrap};
  printf "// http://google.com/url?q=http://dweb.link/ipfs/%s\n",$mh->{wrap};
  printf "// https://l.facebook.com/l.php?u=http://gateway.ipfs.io/ipfs/%s\n",$mh->{wrap};
  open F,'>','ipath.yml';
  printf F "--- # ipath\nIPATH: /ipfs/%s\n",$mh->{wrap};
  printf F "...\n";
  close F;

  my $buf1 = $buf; # again !
  local *T; open T,'>',$yml->{COPYOUT};
  $buf1 =~ s,\%7B\%7BIPATH\%7D\%7D,/ipfs/$mh->{wrap},g;
  $buf1 =~ s,\{\{IPATH\}\},/ipfs/$mh->{wrap},g;
  print T $buf1;
  close T;
  printf "curl -s -s -I http://gateway.ipfs.io/ipfs/%s &\n",$mh->{wrap};
  #system sprintf "curl -s -s -I http://gateway.ipfs.io/ipfs/%s > /dev/null &",$mh->{wrap};
  printf "// http://bitly.com/?url=http://ipns.co/ipfs/%s\n",$mh->{wrap};
  printf "   http://cloudflare-ipfs.com/ipfs/%s\n",$mh->{wrap};
  printf "   http://ipns.co/ipfs/%s\n",$mh->{wrap};
  printf "   http://dweb.link/ipfs/%s\n",$mh->{wrap};
  printf "   http://xmine128.tk/ipfs/%s\n",$mh->{wrap};
  printf "   http://siderus.io/ipfs/%s\n",$mh->{wrap};
  printf "   http://127.0.0.1:8080/ipfs/%s\n",$mh->{wrap};
  system sprintf "firefox http://ocean:8080/ipfs/%s\n",$mh->{wrap};
  # create a redirect file
  local *F; open F,'>',$ENV{HOME}.'/Desktop/INBOX/REDIRECT.htm';
  my $url = sprintf "http://cloudflare-ipfs.com/ipfs/%s",$mh->{wrap};
  printf F <<"EOF",$url,$url,$url,$url,$url;
<meta http-equiv="Location" content="%s">
<meta http-equiv="Refresh" content="5;URL=%s">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
REDIRECT <a href="%s">%s</a>
<br>
<iframe src="%s" width=100% height=100%></iframe>
EOF
  close F;

}

# personal version
{ local *T; open T,'>',"$bname.local";
  $buf0 =~ s,\{\{IPATH\}\},/ipfs/$mh->{wrap},g;
  $buf0 =~ s,\%7B\%7BIPATH\%7D\%7D,/ipfs/$mh->{wrap},g;
print T $buf0;
close T;
}


exit $?;

# -----------------------------------------------------
sub letter {
  my $c = int($_[0]) % 26;
  return chr(0x41 + $c);
}
# -----------------------------------------------------
sub expand { 
  my $bufref = \$_[0];
  my @in = split('</include>',$$bufref);
  my $buf = ''; my $f = 0;
  foreach (@in) {
     if (m/<include\s.*?src=("[^"]+"|[^\s>]+)/) {
       my $file = $1;
       $file =~ tr/"//d; # remove quotes
       if (-e $file) { 
         $f++; printf "inc : %s\n",$file;
         local *F; open F,'<',$file; local $/ = undef; my $content = <F>; close F;
         s/<include.*/$content/ms;
         $buf .= $_;
         # TBD (don't support hierarchical includes yet because of m/include.(/)
         # future version could support nested include ..
       } else {
         print "${red}! -e${nc} '$file'\n";
         $buf .= $_ . '</include>';
       }
     } else {
       $buf .= $_;
     }

  }
  $_[0] = $buf;
  return $f;
}
# -----------------------------------------------------
sub extract_yml {
   my $buf = shift;
   my $isyml = 0;
   my $yml = '';
   my $dbug =  1;
   foreach (split /\n/,$buf) {
      print "DBUG> $_\n" if ($dbug > 1);
      if (/^---\s(?:#.*)?$/) { # /!\ a space after --- is required !
         $isyml = 1;
         print "DBUG> $_\n" if ($dbug > 1);
      }
      if ($isyml == 1) {
         print "DBUG> $_\n" if ($dbug > 1);
         $yml .= $_."\n";
      }
      if (/^\.\.\.\s?$/) {
         $isyml = 0;
      }
   }
   $yml =~ s/\.\.\.\r?\n---\s?(?:#[^\n]*)?\r?\n//gs;
   print "YAML: \"$yml\"\n" if ($dbug > 2);
   use YAML::Syck qw(Load);
   my $data = Load($yml);
   return $data;
}
# -----------------------------------------------------
sub substi { # inplace (buf) substitution ...
  my $yml = shift;
  my $bufref = \$_[0];
  my $c = 0;
  foreach my $key (reverse sort keys %$yml) {
    my $pat = $key; $pat =~ s/-/\-/g;
    next if (ref $yml->{$key} eq 'ARRAY');
    #printf "ref: %s\n",ref($yml->{$key});
    #next unless (ref $yml->{$key} eq '');
    my $value = $yml->{$key};
    print "{{$pat}} -> $value\n" if ($$bufref =~ m/\{\{$pat\}\}/);
    $c += $$bufref =~ s/\{\{$pat\}\}/$value/g;
    $c += $$bufref =~ s/\%7B\%7B$pat\%7D\%7D/$value/g;
  }
  return $c;
}
# -----------------------------------------------------
sub csssubsti { # inplace (buf) class,id substitutions ...
  my $bufref = \$_[0];
  my $c = 0;
  $c  += $$bufref =~ s/>\{#([^\}]+)\}\s*/ id=$1>/g;
  $c  += $$bufref =~ s/>\{\.(\w+)\}\s*/ class=$1>/g;
  return $c;
}

# -----------------------------------------------------
sub get_keylist {
   my $keylist = {};
   my $cmd = sprintf 'ipfs key list -l';
   local *EXEC; open EXEC,"$cmd|" or die $!;
   local $/ = "\n";
   while (<EXEC>) {
     chomp();
     my ($mhash,$key) = split(/\s+/,$_);
     $keylist->{$key.'-ipns-key'} = $mhash;
   }
   return $keylist;

}
# -----------------------------------------------------
sub ipfsadd {
  my $cmd = sprintf 'ipfs add --progress=false --raw-leaves %s',join(' ',map { sprintf '"%s"',$_ } @_);
  local *EXEC; open EXEC, "$cmd|" or die $!; local $/ = "\n";
  my $mh = {};
  while (<EXEC>) {
    print $_ if 1 || $dbug;
    $mh->{$2} = $1 if (m/(?:added\s+)?((?:Qm|zb)\w+)\s+(.*)\s*$/);
    $mh->{'wrap'} = $1 if (m/(?:added\s+)?(Qm\w+)/);
  }
  return $mh;
}
# -----------------------------------------------------
sub get_mhash {
  my $cmd = sprintf 'ipfs add -Q --progress=false --pin=false %s',join(' ',map { sprintf '"%s"',$_ } @_);
  local *EXEC; open EXEC, "$cmd|" or die $!; local $/ = "\n";
  while (<EXEC>) {
    $mh58 = $1 if (m/(?:added\s+)?(Qm\w+)/);
  }
  close EXEC;
  return $mh58;
}
# -----------------------------------------------------
sub get_digest ($@) {
 my $alg = shift;
 my $header = undef;
 use Digest qw();
 local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
 #binmode F unless $_[0] =~ m/\.txt/;
 if ($alg eq 'GIT') {
   $header = sprintf "blob %u\0",(lstat(F))[7];
   $alg = 'SHA-1';
 }
 my $msg = Digest->new($alg) or die $!;
    $msg->add($header) if $header;
    $msg->addfile(*F);
 my $digest = uc( $msg->hexdigest() );
 return $digest; #hex form !
}
# -----------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 while ($n >= 20) {
   my $c = $n % 20;
      $n /= 20;
      $str .= $cs->[$c];
   my $c = $n % 6;
      $n /= 6;
      $str .= $vo->[$c];
 }
 $str .= $cs->[$n];
 return $str; 
}
# -----------------------------------------------------
sub bname { # extract basename etc...
  my $f = shift;
  $f =~ s,\\,/,g; # *nix style !
  my $s = rindex($f,'/');
  my $fpath = ($s > 0) ? substr($f,0,$s) : '.';
  my $file = substr($f,$s+1);

  if (-d $f) {
    return ($fpath,$file);
  } else {
  my $p = rindex($file,'.');
  my $bname = ($p>0) ? substr($file,0,$p) : $file;
  my $ext = lc substr($file,$p+1);
     $ext =~ s/\~$//;
  
  $bname =~ s/\s+\(\d+\)$//;

  return ($fpath,$bname,$ext);

  }

}
# -----------------------------------------------------------------------
sub rev {
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+&fdow($_[0]))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  #print "revision  : $revision ($rev_id, $low_id)\n";
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
# -------------------------------------------------------------------
sub fdow {
   my $tic = shift;
   use Time::Local qw(timelocal);
##     0    1     2    3    4     5     6     7
#y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   our $fdow = (localtime($first))[6];
   #printf "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}
# -----------------------------------------------------
sub hdate { # return HTTP date (RFC-1123, RFC-2822) 
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($_[0]))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  # Mon, 01 Jan 2010 00:00:00 GMT

  my $date = sprintf '%3s, %02d %3s %04u %02u:%02u:%02u GMT',
             $DoW->[$wday],$mday,$MoY->[$mon],$yr4, $hour,$min,$sec;
  return $date;
}
# -----------------------------------------------------
sub get_tics2 {
  my $date = shift;
  my ($hh,$mm,$ss) = (localtime($^T))[2,1,0];
  my ($mo,$dd,$yr4) = split'/',$date;
  use Time::Local qw(timelocal);
  my $tics = timelocal($ss,$mm,$hh,$dd,$mo-1,$yr4);
  return $tics - 1;
}
# -----------------------------------------------------
sub copy ($$) {
 my ($src,$trg) = @_;
 local *F1, *F2;
 return undef unless -r $src;
 return undef if (-e $trg && ! -w $trg);
 open F2,'>',$trg or warn "-w $trg $!"; binmode(F2);
 open F1,'<',$src or warn "-r $src $!"; binmode(F1);
 local $/ = undef;
 my $tmp = <F1>; print F2 $tmp;
 close F1;

 my ($atime,$mtime,$ctime) = (lstat(F1))[8,9,10];
 #my $etime = ($mtime < $ctime) ? $mtime : $ctime;
 utime($atime,$mtime,$trg);
 close F2;
 return $?;
}
# -----------------------------------------------------
sub get_localip {
    use IO::Socket::INET qw();
    # making a connectionto a.root-servers.net

    # A side-effect of making a socket connection is that our IP address
    # is available from the 'sockhost' method
    my $socket = IO::Socket::INET->new(
        Proto       => 'udp',
        PeerAddr    => '198.41.0.4', # a.root-servers.net
        PeerPort    => '53', # DNS
    );
    return '0.0.0.0' unless $socket;
    my $local_ip = $socket->sockhost;

    return $local_ip;
}
# -----------------------------------------------------
sub get_tics { # Friday, 01 Mar 2018 20:03 CET
  my $NoM = {'Jan'=>0,'Feb'=>1,'Mar'=>2,'Apr'=>3,'May'=>4,'Jun'=>5,
       'Jul'=>6,'Aug'=>7,'Sep'=>8,'Oct'=>9,'Nov'=>10,'Dec'=>11};
  my ($date) = @_;
  my ($dow,$dm,$mo,$yr,$t,$tz) = ($date =~ m/(?:(\w+),\s+)?(\d+)\s+(\w+)\s+(\d+)\s+(\S+)(?:\s+(\S+))?/);
  my ($hour,$min,$sec) = split ':',$t,3;
  $ENV{TZ} = $tz;
  my $tic = timelocal($sec,$min,$hour,$dm,$NoM->{$mo},$yr);
  return $tic;
}
# -----------------------------------------------------
sub letter {
  my $c = int($_[0]) % 26;
  return chr(0x41 + $c);
}
# -----------------------------------------------------
1; # vim: nospell
