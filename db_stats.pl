#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Time::HiRes;
use Getopt::Long;
use DBI;
use Math::Round;


my $download = '';
GetOptions('download' => \$download);


# constants

# set up objects
my $dbh = DBI->connect("DBI:Pg:dbname=armory;host=localhost","armory","dicks1234", {pg_enable_utf8 => 1, AutoCommit => 0});
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

=cut
    my $charnames = $dbh->selectcol_arrayref("SELECT name from characters_$realmid");
    foreach my $charname(@{$charnames}) {
        if (exists($allcharnames{$charname})) {
            $allcharnames{$charname}++;
        } else {
            $allcharnames{$charname} = 1;
        }
    }
=cut

	#print "$realmlist->{$realmid}->{'realm'}'s realm id is $realmid\n";
}

my $allscannedpercent = nearest(.01,($totalscannedcharcount / $totalcharcount) * 100);

print "scanned $allscannedpercent% of characters across all US realms ($totalscannedcharcount/$totalcharcount)\n";


print "total of $recipecount recipes found.\n";

print "top 50 names over all US realms:\n";

my $count = 0;

foreach my $name (sort { $allcharnames{$a} <=> $allcharnames{$b} } keys %allcharnames) {
    print "$name\t\t$allcharnames{$name}\n";
    $count++;
    last if $count == 50;
}

$dbh->commit or die $dbh->errstr;


