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

my $realmlist = $dbh->selectall_hashref("SELECT realm_id, realm FROM realms", "realm");

#print Dumper($realmlist);
#die;
open my $connect, '<', "connect.txt" or die "couldn't open connect.txt";

my $cid = 0;

while ( defined( my $line = <$connect>)) {
    #print $line;
    chomp($line);
    my $ins = $dbh->prepare("INSERT INTO connections (id, realm_id) VALUES (?, ?)");
    my @group = split(',',$line);
    foreach my $realm (@group) {
        die "check on $realm!\n" if !exists($realmlist->{$realm});
        $ins->execute($cid, $realmlist->{$realm}->{"realm_id"}) or die $dbh->errstr;
    }
    $cid++;
}

$dbh->commit or die $dbh->errstr;
$dbh->disconnect;


