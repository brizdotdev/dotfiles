#!/bin/bash

METRIC=1 #Should be 0 or 1; 0 for F, 1 for C

if [ -z $1 ]; then
echo
echo "USAGE: weather.sh <locationcode>"
echo
exit 0;
fi

curl -s http://rss.accuweather.com/rss/liveweather_rss.asp\?metric\=${METRIC}\&locCode\=$1 | perl -ne 'use utf8;
if (/Currently/) {
  chomp;/\<title\>Currently: (.*)?\<\/title\>/;
  my @values=split(":",$1);
  my $q = $values[0];
  $values[0]= lc($values[0]);
  if( $values[0] eq "sunny" || $values[0] eq "mostly sunny" || $values[0] eq "partly sunny" || $values[0] eq "intermittent clouds" || $values[0] eq "hazy sunshine" || $values[0] eq "hazy sunshine" || $values[0] eq "hot")
  {
    my $sun = "";
    binmode(STDOUT, ":utf8");
    print "$sun";
  }
  if( $values[0] eq "mostly cloudy" || $values[0] eq "cloudy" || $values[0] eq "dreary (Overcast)" || $values[0] eq "fog")
  {
    my $cloud = "";
    binmode(STDOUT, ":utf8");
    print "$cloud";
  }
  if( $values[0] eq "showers" || $values[0] eq "mostly cloudy w/ showers" || $values[0] eq "mostly cloudy w/ showers" || $values[0] eq "partly sunny w/ showers" || $values[0] eq "t-storms"|| $values[0] eq "mostly cloudy w/ t-storms"|| $values[0] eq "partly sunny w/ t-storms"|| $values[0] eq "rain")
  {
    my $rain = "";
    binmode(STDOUT, ":utf8");
    print "$rain";
  }
  if( $values[0] eq "windy")
  {
    my $wind = "";
    binmode(STDOUT, ":utf8");
    print "$wind";
  }
  if($values[0] eq "flurries" || $values[0] eq "mostly cloudy w/ flurries" || $values[0] eq "partly sunny w/ flurries"|| $values[0] eq "snow"|| $values[0] eq "mostly cloudy w/ snow"|| $values[0] eq "ice"|| $values[0] eq "sleet"|| $values[0] eq "freezing rain"|| $values[0] eq "rain and snow"|| $values[0] eq "cold")
  {
    my $snow = "";
    binmode(STDOUT, ":utf8");
    print "$rain";
  }
  if($values[0] eq "clear" || $values[0] eq "mostly clear" || $values[0] eq "partly cloudy"|| $values[0] eq "intermittent clouds"|| $values[0] eq "hazy moonlight"|| $values[0] eq "mostly cloudy"|| $values[0] eq "partly cloudy w/ showers"|| $values[0] eq "mostly cloudy w/ showers"|| $values[0] eq "partly cloudy w/ t-storms"|| $values[0] eq "mostly cloudy w/ flurries" || $values[0] eq "mostly cloudy w/ snow")
  {
    my $night = "";
    binmode(STDOUT, ":utf8");
    print "$night";
  }
  print "$values[1] $q";
}'
