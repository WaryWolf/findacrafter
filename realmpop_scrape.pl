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
my $url = 'http://wow.realmpop.com/';
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

# set up objects
my $dbh = DBI->connect("DBI:Pg:dbname=armory;host=localhost","armory","dicks1234", {pg_enable_utf8 => 1, AutoCommit => 0});
my $conncache = LWP::ConnCache->new();
$conncache->total_capacity([1]);
my $ua = LWP::UserAgent->new;
$ua->conn_cache($conncache);
binmode(STDOUT, ":utf8");


# grab the list of realms from the realmpop site and parse it

my $starttime = Time::HiRes::gettimeofday();

my $topreq = HTTP::Request->new(GET => $url . 'us.json');
my $response = $ua->request($topreq);
die "http aint workin\n" if !$response->is_success;
my $resdata = $response->content;
my $json = decode_json($resdata);
my $jsonrealms = $json->{"realms"};
my $newtime = Time::HiRes::gettimeofday();
printf("processed realmlist in %.2f seconds\n", $newtime - $starttime);



# grab each realm's json data from realmpop site and save it to the disk
my $realmcount = scalar keys $jsonrealms;
my $realmno = 0;
=for comment
foreach my $realm (keys $jsonrealms) {
    my $realmreq = HTTP::Request->new(GET => $url . 'us-' . $realm . '.json');    
    my $realmres = $ua->request($realmreq);
    if (!$realmres->is_success) {
        die "http aint workin\n";
    }
    my $realmdata = $realmres->content;
    write_file($path.$realm, { binmode => ':utf8' }, $realmdata);
    
    #open(my $realmfile, ">", $path . $realm)
    #    or die "couldn't open file $path $realm \n";
    #print $realmfile $realmdata;
    #close($realmfile);
    my $realmtime = Time::HiRes::gettimeofday();
    my $duration = $realmtime - $newtime;
    $newtime = $realmtime;
    printf("downloaded $realm ($realmno/$realmcount) in %.2f seconds\n", $duration);
    $realmno++;
}
$newtime = Time::HiRes::gettimeofday();
printf("finished downloading realms in %.2f seconds\n", $newtime - $starttime);
=cut



# process saved json files

my $totalcharcount = 0;
$realmno = 0;

opendir (DIR, $path) or die $!;

while (my $realm = readdir(DIR)) {
    next if (($realm eq '..') or ($realm eq '.'));
    #open(my $realmfile, "<", $path . $realm)
    #    or die "couldn't open file $path $realm\n";
    #my $realmdata = do { local $/; <$realmfile> };
    my $realmdata = read_file($path.$realm, {binmode => ':utf8'});
    my $realmjson = decode_json($realmdata);
    my $realmchars = $realmjson->{'characters'};

    my $faction;
    my $realmcharcount = 0;
    $realmno++;
    my @addchars;

    foreach my $gender (keys $realmchars) {
        next if $gender eq 'Unknown';
        foreach my $class (keys $realmchars->{$gender}) {
            next if $class eq 'Unknown';
            foreach my $race (keys $realmchars->{$gender}->{$class}) {
                next if $race eq 'Unknown' or $race eq 'Pandaren' or !$race; 
                $faction = $factions{$race} or die "got a bad race >$race<\n";
                if (ref($realmchars->{$gender}->{$class}->{$race}) eq 'ARRAY') {
                    foreach my $weirdarray (@{$realmchars->{$gender}->{$class}->{$race}}) {
                        foreach my $name (@{$weirdarray}) {
                            #print "adding $name, $realm, $faction\n";
                            $realmcharcount++;
                            push(@addchars, { name => $name, realm => $realm, faction => $faction});
                        }
                    }
                    next;
                }
                foreach my $level (keys $realmchars->{$gender}->{$class}->{$race}) {
                    next if $level eq 'Unknown';
                    #print Dumper($realmchars->{$gender}->{$class}->{$race});
                    foreach my $name (@{$realmchars->{$gender}->{$class}->{$race}->{$level}}) {
                        #print "adding $name, $realm, $faction\n";
                        push(@addchars, { name => $name, realm => $realm, faction => $faction});
                        $realmcharcount++;
                    }
                }
            }
        }
    }
    #bulkaddchars(@addchars);
    bulkaddcharswithcopy(@addchars);
    #$dbh->commit if $realmno / 10 == 0; # herp
    $totalcharcount += $realmcharcount;
    my $parsetime = Time::HiRes::gettimeofday();
    printf("parsed %d chars from %s (%d/%d) in %.2f seconds\n", $realmcharcount, $realm, $realmno, $realmcount, $parsetime - $newtime);
    $newtime = $parsetime;
}
printf("processed %d chars in %d seconds.\n", $totalcharcount, $newtime - $starttime);


#$dbh->commit;
$dbh->disconnect;

# PROGRAM ENDS HERE, FUNCTIONS BELOW

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


