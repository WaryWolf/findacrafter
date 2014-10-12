#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use JSON::XS;
use HTTP::Request;
use Time::HiRes;
use Getopt::Long;
use DBI;
use File::Slurp;

use Coro;
use Coro::LWP;
use EV;
use LWP;
use LWP::ConnCache;

sub threaded_get ($$$);
sub vprint ($);

my $proxy;
my $verbose;
my $checkachieves;
my $charlimit = 100;
my $threadlimit = 20;

GetOptions( 'verbose'           => \$verbose,
            'checkachieves'     => \$checkachieves,
            'proxy=s'           => \$proxy,
	        'charperserver=i'   => \$charlimit,
	        'threads=i'         => \$threadlimit
);

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

my %cma = (
        6884    => 1,
        6885    => 1,
        6888    => 1,
        6889    => 1,
        6892    => 1,
        6899    => 1,
        6893    => 1,
        6902    => 1,
        6894    => 1,
        6905    => 1,
        6895    => 1,
        6908    => 1,
        6896    => 1,
        6911    => 1,
        6897    => 1,
        6914    => 1,
        6898    => 1,
        6917    => 1
);


my %cmamap = (
        6884    => 6885,
        6888    => 6889,
        6892    => 6899,
        6893    => 6902,
        6894    => 6905,
        6895    => 6908,
        6896    => 6911,
        6897    => 6914,
        6898    => 6917
);

# set up objects
my $dbh = DBI->connect("DBI:Pg:dbname=armory;host=localhost","armory","dicks1234", {pg_enable_utf8 => 1, AutoCommit => 0});
my $conncache = LWP::ConnCache->new();
$conncache->total_capacity([1]);
my $ua = LWP::UserAgent->new;
$ua->conn_cache($conncache);
binmode(STDOUT, ":utf8");

my %results;
my $apicount = 0;;
my $twomonthsago = time() - 4838400;


#my $realmlist =  $dbh->selectall_hashref("SELECT DISTINCT(realm) FROM characters", "realm");
my $realmlist = $dbh->selectall_hashref("SELECT realm, realm_id FROM realms", "realm");
my $realmcount = scalar keys $realmlist;
my $realmno = 0;


async { EV::loop };

foreach my $realm (keys %{$realmlist}) {

    my $realmid = $realmlist->{$realm}->{'realm_id'};
    $realmno++;
    # grab already known recipes
    my $known = $dbh->selectall_hashref("SELECT recipe_id FROM recipes", "recipe_id")
        or die $dbh->errstr;

    my $sql = "SELECT char_id FROM characters_$realmid";
    my $charcount = $dbh->do($sql) or die $dbh->errstr;

    vprint "looking at $charlimit of $charcount chars on '$realm' ($realmno/$realmcount)\n";

    my $charlist = $dbh->prepare(
        "SELECT name, char_id 
        FROM characters_$realmid
        WHERE last_checked < '$twomonthsago'
        LIMIT $charlimit");
#        ");
    #my $charlist = $dbh->prepare("SELECT name, char_id FROM characters_$realmid");

    $charlist->execute or die $dbh->errstr;
    die $charlist->errstr if ($charlist->err);


    #my $charrecipeknown = $dbh->selectall_arrayref("SELECT recipe_id FROM char_recipe_$realmid");
    #my $charrecipeknown = $dbh->selectcol_arrayref("SELECT recipe_id FROM char_recipe_$realmid");


    my %recipeMap;
    my $chariter = 1;
    my %timestamps;
    my @oldchars;
    my @noncrafters;
    my $profcount;
    my $threadcount = 0;
    my @threads;
    while (my ($name, $charid) = $charlist->fetchrow_array) {

        if ($apicount > 90000) {
            die "hit requestlimit. will continue later.\n";
        }
        vprint "grabbing info for $name/$realm ($chariter/$charcount)\n";
        $chariter++;


        my $thread = threaded_get($name,$realm,$charid);
        push(@threads,$thread);
        #push(@threads,threaded_get($apireq_url));


        $threadcount++;
        next if $threadcount < $threadlimit;

        #handle threads
        vprint "waiting on threads...\n";

        foreach my $thread (@threads) {
            $thread->join;
        }
        @threads = ();
        $threadcount = 0;


        foreach my $charid (keys %results) {
            my $chardata = $results{$charid}{'content'};
            my $name = $results{$charid}{'name'};
            my $realm = $results{$charid}{'realm'};

            if ($chardata->code == 503) {
                die "Blizzard got mad at us after $apicount requests...\n";
            }

            if ((length($chardata->content) < 5) or ($chardata->code != 200)) {
                push(@oldchars,$charid);
                next;
            }

            my $apijson = decode_json($chardata->content)
		or die "malformed json: $chardata->content\n";
            print "$name is still bad\n" if exists($apijson->{"status"});
            $profcount = 0;
            foreach my $prof ($apijson->{'professions'}->{'primary'}) {
                next if !exists($prof->[0]->{'name'});
                my $profName = $prof->[0]->{'name'};
                if (grep(/^$profName$/,@craftingprofs)) {
                    $profcount++;
                    foreach my $recipe (@{$prof->[0]->{'recipes'}}) {
                        if (exists($recipeMap{$recipe})) {
                            push(@{$recipeMap{$recipe}}, $charid);
                        } else {
                         $recipeMap{$recipe} = [ $charid ];
                        }
                    }
                }
            }
            if ($profcount == 0) {
                push(@noncrafters, $charid);
            }
            next if !exists($apijson->{'feed'});
            $timestamps{$charid} = substr($apijson->{'feed'}->[0]->{'timestamp'}, 0, 10);
            if ($checkachieves) {
                my %cmlist;
                foreach my $ach (@{$apijson->{'achievements'}->{'achievementsCompleted'}}) {
                    next if !exists($cma{$ach});
                    $cmlist{$ach} = 1;
                }
                foreach my $ach (keys %cmlist) {
                    next if !exists($cmamap{$ach});
                    my $achbronze = $cmamap{$ach};
                    print "$name-$realm is a LOSER, they have $ach but not $achbronze!\n" if !exists($cmlist{$achbronze});
                }
            }
        }
        $apicount += $threadlimit;
        undef %results;
    }

    # clean up threads
    foreach my $thread (@threads) {
        $thread->join;
    }


    # make updates to characters (availability, activity, professions)
    my $noncraftcount = scalar @noncrafters;
    my $oldcount = scalar @oldchars;
    vprint "flagging $noncraftcount chars as not crafters\n";
    update_flag('crafter', $realmid, @noncrafters);
    vprint "flagging $oldcount chars as old/unavailable\n";
    update_flag('available', $realmid, @oldchars);

    # update timestamps
    my $nowtime = time();
    my $timeupd = $dbh->prepare("UPDATE characters_$realmid SET last_active = ?, last_checked = ? WHERE char_id = ?");
    foreach my $charid (keys %timestamps) {
        $timeupd->execute($timestamps{$charid}, $nowtime, $charid) or die $dbh->errstr;
    }


    my $count = 0;
    
    # populate the recipes table
    my $ins_recipe = $dbh->prepare("INSERT INTO recipes (recipe_id, name) VALUES (?, ?)");
    foreach my $spellid (keys %recipeMap) {
        next if exists($known->{$spellid});
        my $spellname = get_spell_name($spellid);
        $ins_recipe->execute($spellid, $spellname) or die $dbh->errstr;
        vprint "getting name for $spellid = $spellname\n";
        $count++;
    }
    $dbh->commit;
    vprint "inserted $count new recipes into the db\n" if $count > 0;
    $count = 0;



    # populate char_recipes table
    #my $ins_char = $dbh->prepare("INSERT INTO char_recipe_$realmid (recipe_id, char_id) VALUES (?, ?)");
    my $rows;
    foreach my $recipe (keys %recipeMap) {

        # get a list of all currently known crafters of this recipe
        # so we don't insert something that already exists
        #my $knowncrafters = $dbh->selectall_hashref("SELECT char_id FROM char_recipe_$realmid WHERE recipe_id = $recipe", "char_id");

        foreach my $charid (@{$recipeMap{$recipe}}) {
            #next if exists ($knowncrafters->{$charid});
            $rows = $dbh->do("INSERT INTO char_recipe_$realmid (recipe_id, char_id) SELECT $recipe, $charid WHERE NOT EXISTS (SELECT * FROM char_recipe_$realmid WHERE recipe_id = $recipe AND char_id = $charid)");
            #$ins_char->execute($recipe, $charid) or die $dbh->errstr;
            $count += $rows;
        }
    }
    vprint "inserted $count recipe-char relationships into the db\n";
    $dbh->commit;

}



$dbh->disconnect;

# PROGRAM ENDS HERE, FUNCTIONS BELOW



sub threaded_get ($$$) {
    #my ($url) = @_;
    my $name = shift;
    my $realm = shift;
    my $charid = shift;
    my $fullurl;
    if ($checkachieves) {
        $fullurl = "$url/$realm/$name?fields=professions,feed,achievements";
    } else {
        $fullurl = "$url/$realm/$name?fields=professions,feed";
    }
    return async {
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        if (defined($proxy)) {
            $ua->proxy('http',$proxy);
        }
        my $req = HTTP::Request->new(GET => $fullurl);
        my $res = $ua->request($req);
        $results{$charid}{'content'} = $res;
        $results{$charid}{'realm'} = $realm;
        $results{$charid}{'name'} = $name;
    }
}


sub update_flag {
    my ($flag, $realmid, @chars) = @_;
    my $timenow = time();
    my $upd = $dbh->prepare("UPDATE characters_$realmid SET $flag = ?, last_checked = ? WHERE char_id = ?");
    foreach (@chars) {
        $upd->execute('f', $timenow, $_) or die $dbh->errstr;
    }
    $dbh->commit;
}


sub get_spell_name {
    
    my ($spellid) = @_;

    my $url = "http://us.battle.net/api/wow/spell/$spellid";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);
    $apicount++;
    die "grabbing $url failed: ",$res->code," after $apicount requests\n" if !$res->is_success;
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

# prints if --verbose set.
sub vprint ($) {
    my ($msg) = @_;
    print $msg if defined($verbose);
}
