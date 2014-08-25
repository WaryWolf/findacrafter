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


# grab the recipes for a realm

my $sql = "SELECT char_id FROM characters WHERE realm = 'blackwing-lair'";
my $charcount = $dbh->do($sql);

print "looking at $charcount chars on 'blackwing-lair'\n";

my $charlist = $dbh->prepare("SELECT name, realm, char_id FROM characters WHERE realm = 'blackwing-lair' LIMIT 100");

$charlist->execute or die $DBI::errstr;
die $charlist->errstr if ($charlist->err);

my $totalrecipecount;
my %recipeMap;
my $chariter = 0;
while (my ($name, $realm, $charid) = $charlist->fetchrow_array) {
    #my $recipecount = 0;
    print "grabbing info for $name/$realm ($chariter/$charcount)\n";
    $chariter++;
    my $apireq_url = "$url/$realm/$name?fields=professions";
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
=for comment
                if (exists($recipeMap{$recipe})) {
                    $recipeMap{$recipe} += 1;
                } else {
                    $recipeMap{$recipe} = 1;
                }
=cut
                if (exists($recipeMap{$recipe})) {
                    push(@{$recipeMap{$recipe}}, $charid);
                } else {
                 $recipeMap{$recipe} = [ $charid ];
                }
                #$recipecount++;
            }
        }
    }
    #$totalrecipecount += $recipecount;
}

my $count = 0;
my $total = scalar keys %recipeMap;
# populate the recipes table
my $ins_recipe = $dbh->prepare("INSERT INTO recipes (recipe_id, name, bop) VALUES (?, ?, ?)");
foreach my $spellid (keys %recipeMap) {
    my $spellname = get_spell_name($spellid);
    $ins_recipe->execute($spellid, $spellname, 'true') or die $dbh->errstr;
    print "getting name for $spellid = $spellname ($count/$total)\n";
    $count++;
}
print "inserted $count unique recipes into the db\n";
$count = 0;

print "inserting char-recipe relations into the db, this may take some time...\n";
# populate char_recipes table
my $ins_char = $dbh->prepare("INSERT INTO char_recipe (recipe_id, char_id) VALUES (?, ?)");
foreach my $recipe (keys %recipeMap) {
    foreach my $charid (@{$recipeMap{$recipe}}) {
        $ins_char->execute($recipe, $charid) or die $dbh->errstr;
        $count++;
    }
}
print "inserted $count recipe-char relationships into the db\n";



#while (my ($key, $value) = each %recipeMap) {
#    print "saw $key $value times\n";
#}
#my $uniques = scalar keys %recipeMap;
#print "found $uniques recipes\n";




$dbh->commit;
$dbh->disconnect;

# PROGRAM ENDS HERE, FUNCTIONS BELOW


#TODO this thing needs to insert the array of recipes into char_recipe
# however you should make sure the recipe exists in the recipes table
sub addrecipes {

    my ($name, $realm, @recipes) = @_;
    #my $ins = $dbh->prepare("INSERT INTO 

}


sub get_spell_name {
    
    my ($spellid) = @_;

    my $url = "http://us.battle.net/api/wow/spell/$spellid";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);
    die "grabbing $url failed: ",$res->code,"\n" if !$res->is_success;
    my $json = decode_json($res->content);
    die "bad request at $url: $json->{'status'}\n" if exists($json->{'status'});
    return $json->{'name'} or die "spell name for $spellid not found\n";
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


