#!/usr/bin/perl
use strict;
use warnings;

my $fields = "id=42; id=7";
$fields =~ s/([a-z]+)=([0-9]+)/$1:$2/g;
my $named = "elisa";
$named =~ s/(?<word>[a-z]+)/<$+{word}>/g;
my $alternatives = "cat dog";
$alternatives =~ s/(cat|dog)/<$1>/g;
my $anchors = "abc";
$anchors =~ s/^/>/g;
$anchors =~ s/$/!/g;
my $deleted = "banana";
$deleted =~ s/na//g;
my $unchanged = "nothing";
$unchanged =~ s/[0-9]+/x/g;
my $empty = "";
$empty =~ s/^/x/g;
my $eof = "abc";
$eof =~ s/$/!/g;

print join("\n", $fields, $named, $alternatives, $anchors, $deleted, $unchanged, $empty, $eof), "\n";
