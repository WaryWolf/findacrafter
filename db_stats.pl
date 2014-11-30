#!/usr/bin/perl

use strict;
use warnings;


use File::Basename;
use lib dirname (__FILE__);
require "conf.pl";
our $db_login;
our $db_pass;

use Data::Dumper;
use Time::HiRes;
use Getopt::Long;
use DBI;
use Math::Round;
use Text::Unidecode qw(unidecode);

my $names;
GetOptions('names' => \$names);


# constants



# set up objects
my $dbh = DBI->connect("DBI:Pg:dbname=armory;host=localhost",$db_login,$db_pass, {pg_enable_utf8 => 1, AutoCommit => 0});
binmode(STDOUT, ":utf8");


#$dbh->do("SET client_min_messages = WARNING") or die $dbh->err;

my $realmlist = $dbh->selectall_hashref("SELECT realm_id, realm FROM realms", "realm_id");

#print Dumper($realmlist);

my %allcharnames;

my $totalcharcount = 0;
my $totalscannedcharcount = 0;

my ($res) = $dbh->selectcol_arrayref("SELECT COUNT(*) FROM recipes");
my $recipecount = $res->[0];


foreach my $realmid (keys $realmlist) {
	my $realmname = $realmlist->{$realmid}->{'realm'};

	my $res = $dbh->selectcol_arrayref("SELECT COUNT(*) FROM characters_$realmid");
	my $charcount = $res->[0];

	$res = $dbh->selectcol_arrayref("SELECT COUNT(*) FROM characters_$realmid WHERE last_checked > 0");
	my $scannedcharcount = $res->[0];

	my $scannedpercent = nearest(.01,($scannedcharcount / $charcount) * 100);

	print "scanned $scannedpercent% of $realmname ($scannedcharcount/$charcount)\n";

	$totalcharcount += $charcount;
	$totalscannedcharcount += $scannedcharcount;

	if ($names) {
		my $charnames = $dbh->selectcol_arrayref("SELECT name from characters_$realmid");
		
		foreach my $charname(@{$charnames}) {
			my $asciiname = unidecode($charname);
		#print "$charname\n" if $asciiname eq "Death";
			if (exists($allcharnames{$asciiname})) {
				$allcharnames{$asciiname}++;
			} else {
				$allcharnames{$asciiname} = 1;
			}
		}
	}
}

my $allscannedpercent = nearest(.01,($totalscannedcharcount / $totalcharcount) * 100);

print "scanned $allscannedpercent% of characters across all US realms ($totalscannedcharcount/$totalcharcount)\n";


print "total of $recipecount recipes found.\n";
if ($names) {

    my $top = 200;
	print "top $top names over all US realms:\n";

	my $count = 0;

    foreach my $name (keys %allcharnames) {
        delete $allcharnames{$name} if $allcharnames{$name} < 3;
    }


	foreach my $name (sort { $allcharnames{$b} <=> $allcharnames{$a} } keys %allcharnames) {
	    print "$name\t\t$allcharnames{$name}\n";
	    $count++;
	    last if $count == $top;
	}
}

$dbh->commit or die $dbh->errstr;


