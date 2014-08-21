#!/usr/bin/perl
use strict;
use warnings;

use DBI;

my $dbh = DBI->connect("DBI:Pg:dbname=armory;host=localhost","armory","dicks1234");



sub addchar {
    my ($name, $realm, $faction, $flag) = @_;
    my $ins = $dbh->prepare("INSERT INTO characters (name, realm, faction) VALUES ('$name', '$realm', '$faction')");
    $ins->execute();
    
    # return the id of the char you just inserted, if $flag is set
    if ($flag) {
        my $id = $dbh->last_insert_id(undef,undef,"characters",undef);
        return $id;
    }

}


my $sth = $dbh->prepare("SELECT * FROM characters");
$sth->execute();

while (my $ref = $sth->fetchrow_hashref()) {
    print "$ref->{'name'} is on realm $ref->{'realm'} on faction $ref->{'faction'}\n";
}

$dbh->disconnect();
