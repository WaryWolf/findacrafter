#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use JSON::XS;
use HTTP::Request;
use LWP;
use LWP::ConnCache;
use Time::HiRes;
use Getopt::Long;
use DBI;
use File::Slurp;

#my $mode = '';

#GetOptions('mode=s' => \$mode);
#if (($mode ne 'download') and ($mode ne 'process')) {

# constants
my $url = 'http://us.battle.net/api/wow/character';
my $path = "json/";

my %factions = (
        'Orc'       => 'H',
        'Undead'    => 'H',
        'Tauren'    => 'H',
        'Troll'     => 'H',
        'Blood Elf' => 'H',
        'Goblin'    => 'H',
        'Human'     => 'A',
        'Dwarf'     => 'A',
        'Gnome'     => 'A',
        'Night Elf' => 'A',
        'Worgen'    => 'A',
        'Draenei'   => 'A',
        'PandarenH' => 'H',
        'PandarenA' => 'A',
);

my @craftingprofs = ( 
        'Alchemy',
        'Blacksmithing',
        'Enchanting',
        'Engineering',
        'Inscription',
        'Jewelcrafting',
        'Leatherworking',
        'Tailoring',
);

# set up objects
my $dbh = DBI->connect("DBI:Pg:dbname=armory;host=localhost","armory","dicks1234", {pg_enable_utf8 => 1, AutoCommit => 0});
my $conncache = LWP::ConnCache->new();
$conncache->total_capacity([1]);
my $ua = LWP::UserAgent->new;
$ua->conn_cache($conncache);
binmode(STDOUT, ":utf8");


=for comment
my $topreq = HTTP::Request->new(GET => 'http://wow.realmpop.com/us.json');
my $response = $ua->request($topreq);
die "http aint workin\n" if !$response->is_success;
my $resdata = $response->content;
my $json = decode_json($resdata);
my $jsonrealms = $json->{"realms"};

foreach my $realm (keys $jsonrealms) {
    my $realmname = $jsonrealms->{$realm}->{"name"};
    print "$realm -> $realmname\n";
}
=cut

my $charlist = $dbh->prepare("SELECT name, realm FROM characters WHERE realm = 'amanthul' LIMIT 50");

$charlist->execute or die $DBI::errstr;
die $charlist->errstr if ($charlist->err);

my $totalrecipecount;
my %recipeMap;
while (my ($name, $realm) = $charlist->fetchrow_array) {
    my $recipecount = 0;
    print "grabbing info for $name/$realm\n";
    my $apireq_url = "$url/$realm/$name?fields=professions,guild";
    my $apireq = HTTP::Request->new(GET => $apireq_url);
    my $apires = $ua->request($apireq);
    next if $apires->code != 200;
    #die "grabbing $apireq_url failed: ",$apires->code,"\n" if !$apires->is_success;
    if ((length($apires->content) < 5) or ($apires->code == 404)) {
        #print "got a bad response, skipping $name\n";
        # delete the char here or something
        next;
    }
    my $apijson = decode_json($apires->content);
    print "$name is still bad\n" if exists($apijson->{"status"});
    #print "$name $realm\n";
    
    foreach my $prof ($apijson->{'professions'}->{'primary'}) {
        #print Dumper($prof->[0]);
        #die;
        next if !exists($prof->[0]->{'name'});
        my $profName = $prof->[0]->{'name'};
        if (grep(/^$profName$/,@craftingprofs)) {
            foreach my $recipe (@{$prof->[0]->{'recipes'}}) {
                if (exists($recipeMap{$recipe})) {
                    $recipeMap{$recipe} += 1;
                } else {
                    $recipeMap{$recipe} = 1;
                }
                $recipecount++;
            }
        }
    }
    $totalrecipecount += $recipecount;
    #print Dumper($apijson);
    #die "successfully got $apireq_url\n";
}
while (my ($key, $value) = each %recipeMap) {
    print "saw $key $value times\n";
}
my $uniques = scalar keys %recipeMap;
print "found $uniques recipes\n";

#$dbh->commit;
$dbh->disconnect;

# PROGRAM ENDS HERE, FUNCTIONS BELOW


#TODO this thing needs to insert the array of recipes into char_recipe
# however you should make sure the recipe exists in the recipes table
sub addrecipes {

    my ($name, $realm, @recipes) = @_;
    #my $ins = $dbh->prepare("INSERT INTO 

}


sub addchar {
    my ($name, $realm, $faction, $flag) = @_;
    my $ins = $dbh->prepare("INSERT INTO characters (name, realm, faction) VALUES ('$name', '$realm', '$faction')");
    $ins->execute();

    # return the id of the char you just inserted, if $flag is set
    #if ($flag) {
    #    my $id = $dbh->last_insert_id(undef,undef,"characters",undef);
    #    return $id;
    #}
}

sub bulkaddchars {

    my (@addchars) = @_;

    my $ins = $dbh->prepare("INSERT INTO characters (name, realm, faction) VALUES (?, ?, ?)") or die $dbh->errstr;
    foreach (@addchars) {
        #print "inserting $_->{name} $_->{realm} $_->{faction}\n";
        $ins->execute($_->{name}, $_->{realm}, $_->{faction}) or die $dbh->errstr;
    }
 
    $dbh->commit or die $dbh->errstr;
}

sub bulkaddcharswithcopy {

    my (@addchars) = @_;
    
    $dbh->do("COPY characters (name, realm, faction) FROM STDIN WITH DELIMITER ','")
        or die $dbh->errstr;

    foreach(@addchars) {
        $dbh->pg_putcopydata("$_->{name},$_->{realm},$_->{faction}\n")
            or die $dbh->errstr;
    }
    $dbh->pg_putcopyend();
    $dbh->commit or die $dbh->errstr;
}


