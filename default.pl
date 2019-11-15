#!/usr/binr/env perl
# vim: nospell ft=perl

# DEFAULT SUBSTITUTION for YML substitution

my $yml = {};
use lib $ENV{SITE}.'/lib';
use UTIL qw(fname);
my ($fpath,$fname,$bname,$ext) = &fname($0);
my $ymlf = $bname . '.yml';

$yml->{WWW} = $ENV{HOME} . '/odrive/Tommy/public_html'; # <---
$yml->{SEARCH} = 'https://seeks.hsbp.org/?language=en&engines=google,duckduckgo,qwant,ixquick,startpage&q';
$yml->{SEARX} = 'https://ipfs.gc-bank.tk/ipns/searx.neocities.org/?q';
$yml->{SEARXES} = 'https://searxes.danwin1210.me/?lg=en-US&search_this';
$yml->{SIMIL} = 'http://www.google.com/searchbyimage?btnG=1&hl=en&image_url';
$yml->{GOO} = 'http://google.com/search?bti=1&q';
$yml->{DUCK} = 'http://duckduckgo.com/?q'; # <---


$yml->{IPROXY} = 'http://ipns.co';

$yml->{GW} = 'http://gateway.ipfs.io';
$yml->{ZGW} = 'http://0.0.0.0:8080';
$yml->{GCGW} = 'http://ipfs.gc-bank.tk';
$yml->{'2GGW'} = 'http://ipfs.2gether.cf';

$yml->{IPH} = 'http://iph.heliohost.org/IPHS';
$yml->{AHE} = 'http://iph.heliohost.org/AHE';

$yml->{HELIO} = 'http://iph.heliohost.org';
$yml->{IPNS} = 'http://iph.heliohost.org/ipns';
$yml->{IMAGES} = 'http://iph.heliohost.org/ipns/images';

$yml->{SAVE} = 'https://web.archive.org/save';
$yml->{GT} = 'https://translate.google.com/translate?sl=auto&tl=en&js=y&prev=_t&hl=en&ie=UTF-8&u';


# Symbols
$yml->{'TM'} = '&trade;';
$yml->{'SM'} = '&#8480;';
$yml->{'<3'} = '&#9825;';
$yml->{':)'} = '&#9786;';

# Redirects
$yml->{'URL'} = 'https://www.google.com/url?q';
$yml->{'URL'} = 'https://getpocket.com/redirect?url';
$yml->{'URL'} = 'https://duck.co/redir/?u=';
$yml->{'URL'} = 'https://ad.zanox.com/ppc/?32249347C62314846&ulp=%5B%5B%%s%5D%5D';
$yml->{'FB'} = 'https://l.facebook.com/l.php?u=';
$yml->{'WB'} = 'https://web.archive.org/web/';


use YAML::Syck qw(DumpFile);

DumpFile($ymlf,$yml);
print $ymlf,"\n";
exit $?;
1;
