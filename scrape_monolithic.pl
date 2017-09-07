#!/usr/bin/perl

###############################################################################
# Odds scraping program, Angelos Karageorgiou <angelos@unix.gr>
#
# Please note that the code for this project has evolved in many steps
# As procs were added the code became more intelligent
# eventually it will grow up to be object oriented
#
##############################################################################


# Notes to self
# novibet and goalbet must have all the bets not just the top page ones
#

require 'utf8_heavy.pl';
use strict;
use utf8;
use threads;
use Thread::Queue;
use POSIX ":sys_wait_h";
use Sys::Syslog; 
use Mojo::DOM;
use Getopt::Long;
use DBI;
use Switch;
use LWP::Simple;
use HTML::TableExtract;
use Try::Tiny;
use Time::localtime;
use Encode qw(decode encode);
use WWW::Mechanize::Firefox;
use List::Util 'shuffle';
#use Scalar::Util qw(blessed dualvar isweak readonly refaddr reftype tainted
#                              weaken isvstring looks_like_number set_prototype);

use Scalar::Util qw(looks_like_number);

######################################################################
# sub definitions
######################################################################
sub domysql($$$$$$$$$);
sub real_mysql($$$$$$$$$);
sub scoreupdate_by_couponid($$$$$$);
sub scoreupdate_by_opp2($$$$$$);
sub usage();
sub myuc($$);
sub vprint($);
sub dprint($);
sub read_data($);
sub now();
sub par_do($$$$);
sub par_do_threaded($$$$);
sub par_do_forked($$$$);
sub deqsql;
sub newFirefox;
sub show_screen($);
sub trim($);
sub timed_get($$);


######################################################################
# requirements and where to find them
######################################################################
BEGIN {
	push @INC,".";
	push @INC,"/root/scrapers";
}

#nodata.info's own code
require 'nodata_lib.pl';
require 'betonews.pl';
require 'opapv2.pl';
require '1xbetcyv3.pl';
require 'stoiximan.pl';
require 'mybet.pl';
require 'sportingbet.pl';
require 'bet365.pl';
require 'betcosmos.pl';
require 'novibet.pl';
require 'goalbet.pl';
require 'magicbet.pl';



######################################################################
# global vars;
######################################################################

# an attempt to normalize team names
my %OPP_TRANSLATIONS = (
	'ΣΤΕΑΟΥΑ Β\.'			=> 'ΣΤΕΑΟΥΑ ΒΟΥΚΟΥΡΕΣΤΙΟΥ',
	'ΝΤΙΝΑΜΟ ΒΟΥΚ\.'		=> 'ΝΤΙΝΑΜΟ ΒΟΥΚΟΥΡΕΣΤΙΟΥ',
	'ΝΤΙΝΑΜΟ ΒΟΥΚΟΥΡ\.'		=> 'ΝΤΙΝΑΜΟ ΒΟΥΚΟΥΡΕΣΤΙΟΥ',
	'ΝΤΙΝΑΜΟ ΤΥΦΛ\.'		=> 'ΝΤΙΝΑΜΟ ΤΥΦΛΙΔΑΣ',
	'ΣΠΟΡΤΙΝΓΚ Λ\.'			=> 'ΣΠΟΡΤΙΝΓΚ ΛΙΣΣΑΒΟΝΑΣ',
	'ΣΠΟΡΤΙΝΓΚ ΛΙΣ\.'		=> 'ΣΠΟΡΤΙΝΓΚ ΛΙΣΣΑΒΟΝΑΣ',
	'ΜΠΑΓΕΡΝ ΜΟΝ\.'			=> 'ΜΠΑΓΕΡΝ ΜΟΝΑΧΟΥ',
	'ΜΑΝΤΣΕΣΤΕΡ Γ\.'		=> 'ΜΑΝΤΣΕΣΤΕΡ ΓΙΟΥΝΑΙΤΕΝΤ',
	'ΑΔΕΛΑΙΔΑ Γ\.'			=> 'ΑΔΕΛΑΙΔΑ ΓΙΟΥΝΑΙΤΕΝΤ',
	'ΦΟΡΤΟΥΝΑ ΝΤ\.'			=> 'ΦΟΡΤΟΥΝΑ ΝΤΙΣΕΛΝΤΟΡΦ',
	'ΦΟΡΤΟΥΝΑ ΝΤΙΣ\.'		=> 'ΦΟΡΤΟΥΝΑ ΝΤΙΣΕΛΝΤΟΡΦ',
	'ΠΑΡΙ Σ\.Ζ\.'			=> 'ΠΑΡΙ ΣΕΝ ΖΕΡΜΕΝ',
	'ΤΣΣΚΑ Μ\.'				=> 'ΤΣΣΚΑ ΜΟΣΧΑΣ',
	'ΜΑΚΑΜΠΙ Τ\.Α\.'		=> 'ΜΑΚΑΜΠΙ ΤΕΛ ΑΒΙΒ',
	' ΓΙΟΥΝ\.'				=> ' ΓΙΟΥΝΑΙΤΕΝΤ',
	' Γ\.'					=> ' ΓΙΟΥΝΑΙΤΕΝΤ',
	' ΤΖ\.'					=> ' ΤΖΟΥΝΙΟΡΣ',
	' ΤΖΟΥΝ\.'				=> ' ΤΖΟΥΝΙΟΡΣ',
	'ΑΙΝΤΡ\.'				=> 'ΑΙΝΤΡΑΧΤ',
	'ΝΤΙΣΕΛΝΤΟΛΦ'			=> 'ΝΤΙΣΕΛΝΤΟΡΦ',
	'ΑΤΛ. ΓΚΟΙΑΝΙΕΝΣΕ'		=> 'ΑΤΛΕΤΙΚΟ ΓΚΟΙΑΝΙΕΝΣΕ',
	'ΜΠΡΑΖΙΛ ΝΤΕ ΠΕΛΟΤΑΣ'	=> 'ΜΠΡΑΖΙΛ ΠΕΛΟΤΑΣ',
	'ΓΚΟΙΝΙΕΝΣΕ'			=> 'ΓΚΟΙΑΝΙΕΝΣΕ',
	'ΜΕΡΚΟΥΡΙ'				=> 'ΜΕΡΚΙΟΥΡΙ',
	'ΜΠΟΡΟΥΣΣΙΑ'			=> 'ΜΠΟΡΟΥΣΙΑ',
	'ΟΚΛΑΧΟΜΑ ΘΑΝΤΕΡ'		=> 'ΟΚΛΑΧΟΜΑ Σ. ΘΑΝΤΕΡ',
	'ATLANTA DREAM'			=> 'ΑΤΛΑΝΤΑ ΝΤΡΙΜ',
	'ΟΥΝΙΚΣ'				=> 'ΟΥΝΙΞ',
	'^ΟΥΝΙΞ$'				=> 'ΟΥΝΙΞ ΚΑΖΑΝ',
	'\&amp\;'				=> '\&',
	'\&AMP\;'				=> '\&',
	'ΣΠΑΡΤΑΚ Μ\.$'			=> 'ΣΠΑΡΤΑΚ ΜΟΣΧΑΣ',
	'ΑΟΥΣΤΡΙΑ Β\.$'			=> 'ΑΟΥΣΤΡΙΑ ΒΙΕΝΝΗΣ',
	'ΑΟΥΣΤΡΙΑ ΣΑΛ\.$'		=> 'ΑΟΥΣΤΡΙΑ ΣΑΛΤΖΜΠΟΥΡΓΚ',
	'ΒΑΚΕΡ ΙΝΣ\.$'			=> 'ΒΑΚΕΡ ΙΝΣΜΠΟΥΡΓΚ',
	'ΒΙΚΙΝΓΚΟΥΡ ΡΕΙΚ\.$'	=> 'ΒΙΚΙΝΓΚΟΥΡ ΡΕΙΚΙΑΒΙΚ',
	'ΓΙΑΝΓΚΣΟΥ Σ\.$'		=> 'ΓΙΑΝΓΚΣΟΥ ΣΧΟΥΝΤΙΑΝ',
	'ΜΠΡΙΣΤΟΛ Ρ\.$'			=> 'ΜΠΡΙΣΤΟΛ ΡΟΒΕΡΣ',
	'ΝΤΕΠΟΡΤΙΒΟ ΜΟΥΝ\.$'	=> 'ΝΤΕΠΟΡΤΙΒΟ ΜΟΥΝΙΣΙΠΑΛ',
	'ΟΥΝΙΟΝ ΒΕΡ\.$'			=> 'ΟΥΝΙΟΝ ΒΕΡΟΛΙΝΟΥ',
	'ΠΑΚΟΣ ΦΕΡ\.$'			=> 'ΠΑΚΟΣ ΦΕΡΕΙΡΑ',
	'ΡΑΝΤΝΙΚ ΣΟΥΡΝΤ\.$'		=> 'ΡΑΝΤΝΙΚ ΣΟΥΡΝΤΟΥΛΙΤΣΑ',
	'ΡΙΒΕΡ ΠΛΕΙΤ ΕΚΟΥ\.$'	=> 'ΡΙΒΕΡ ΠΛΕΙΤ ΕΚΟΥΑΔΟΡ',
	'ΡΙΒΕΡ ΠΛΕΙΤ ΕΚΟΥ\.$'	=> 'ΡΙΒΕΡ ΠΛΕΙΤ ΕΚΟΥΑΔΟΡ',
	'ΣΑΧΤΑΡ ΝΤ\.$'			=> 'ΣΑΧΤΑΡ ΝΤΟΝΕΤΣΚ',
	'ΤΖΑΓΚΟΥΑΡΕΣ ΝΤΕ ΚΟΡ\.$'=> 'ΤΖΑΓΚΟΥΑΡΕΣ ΝΤΕ ΚΟΡΔΟΒΑ',
	'ΑΙΝΤΡΑΧΤ ΦΡ\.$'		=> 'ΑΙΝΤΡΑΧΤ ΦΡΑΝΚΦΟΥΡΤΗΣ',
	'ΑΟΥΣΤΡΙΑ Β\.$'			=> 'ΑΟΥΣΤΡΙΑ ΒΙΕΝΝΗΣ',
	'ΒΙΣΛΑ ΚΡ\.$'			=> 'ΒΙΣΛΑ ΚΡΑΚΟΒΙΑΣ',
	'ΖΑΓΚΛΕΜΠΙΕ ΣΟΣ\.$'		=> 'ΖΑΓΚΛΕΜΠΙΕ ΣΟΣΝΟΒΙΕΤΣ',
	'ΖΕΜΠΛΙΝ ΜΙΧ\.$'		=> 'ΖΕΜΠΛΙΝ ΜΙΧΑΛΟΒΤΣΕ',
	'ΛΕΙΚΝΙΡ ΡΕΙΚ\.$'		=> 'ΛΕΙΚΝΙΡ ΡΕΙΚΙΑΒΙΚ',
	'ΜΠΡΙΣΤΟΛ Σ\.$'			=> 'ΜΠΡΙΣΤΟΛ ΣΙΤΙ',
	'ΝΤΕΠΟΡΤΙΒΟ ΜΟΥΝ\.$'	=> 'ΝΤΕΠΟΡΤΙΒΟ ΜΟΥΝΙΣΙΠΑΛ',
	'ΠΑΙΝΤΕ ΛΙΝ\.$'			=> 'ΠΑΙΝΤΕ ΛΙΝΑΜ.',
	'ΠΟΡΤ ΜΕΛΒΟΥΡΝΗ Σ\.$'	=> 'ΠΟΡΤ ΜΕΛΒΟΥΡΝΗ ΣΑΡΚΣ',
	'ΡΙΒΕΡ ΠΛΕΙΤ ΕΚΟΥ\.$'	=> 'ΡΙΒΕΡ ΠΛΕΙΤ ΕΚΟΥΑΔΟΡ',
	'ΣΠΑΡΤΑΚ ΣΟΥΜΠ\.$'		=> 'ΣΠΑΡΤΑΚ ΣΟΥΜΠΟΤΙΤΣΑ',
	'ΣΤΑΝΤΑΡ Λ\.$'			=> 'ΣΤΑΝΤΑΡ ΛΙΕΓΗΣ',
	'ΤΖΑΓΚΟΥΑΡΕΣ ΝΤΕ ΚΟΡ\.$'=> 'ΤΖΑΓΚΟΥΑΡΕΣ ΝΤΕ ΚΟΡΔΟΒΑ',
);

my $verbose	=0;		# a lot of detail
my $debug	=0;		# dumps SQL details
my $site	="";
my $database="bets";
my $dbhost	= "dbhost";
my $dbport	= 3306;
my $dbuser	= "bets";
my $dbpassword="wsbpB5}L3";
my $par_tabs=0;		# number of tabs in parallel
my $pastdays=1;		# how many days in the past to fetch data
my $TIMEOUT=300;	# 5minutes ought to do it
my $dryrun=0;		# no DB work
my $nosyslog=0;		# console output
my $dev=0;			# development mode
#
# parallelization, disable to fall back to forks
#
my $threaded=1;

#######################################################################
# WE START HERE
#######################################################################
GetOptions (
		"debug"		=> \$debug,
		"tabs=i"	=> \$par_tabs,
		"pastdays=i"=> \$pastdays,
		"verbose"	=> \$verbose,
		"dryrun"	=> \$dryrun,
		"dry_run"	=> \$dryrun,
		"dry"		=> \$dryrun,
		"nosyslog"	=> \$nosyslog,
		"no_syslog"	=> \$nosyslog,
		"dev"		=> \$dev,
		"timeout=i"	=> \$TIMEOUT,
		"site=s"	=> \$site) or usage();

usage() if ( $site eq "" || $par_tabs <0 );

#developer mode
if ($dev) {
	$dryrun		=1;
	$nosyslog	=1;
	$verbose	=1;
	$debug		=1;
	$TIMEOUT	=10;
}

# sanity check
if ( ! $dryrun ) {
	my $dbh = getdbh();
	$dbh->disconnect;
}

# this is 10 times faster than plain forking per tab
my $sqlq = Thread::Queue->new();    # A new empty queue
my $thr = threads->create(\&deqsql)->detach();

openlog('scrapers', 'nofatal', 'local0') unless ($nosyslog);

#
# This is all the work 
#
vprint "----------------------- $site -------------------------------------";
switch ($site) {

	case "betcosmos" { 
			dprint "Starting $site FootBall\n";
			do_betcosmos_scores('http://www.betcosmos.com/index.php?page=apotelesmata_pame_stoixima' ,$verbose,'opap');
			dprint "Done $site FootBall\n";
		}


	case "opap" { 
			$par_tabs++; # can do more
			dprint "Starting $site FootBall\n";
			do_opap_soccer('http://praktoreio.pamestoixima.gr/el/retail-betting#r/' ,$verbose,$site);
			dprint "Done $site Football\n";

			dprint "Starting $site Basket\n";
			do_opap_basket('http://praktoreio.pamestoixima.gr/el/basket-retail#r/'  ,$verbose,$site);
			dprint "Done $site Basket\n";
		}

	case "stoiximan" { 
			dprint "Starting $site FootBall\n";
			do_stoiximan_soccer('https://www.stoiximan.gr/greek-coupon/Soccer-FOOT' ,	$verbose,$site);
			dprint "Done $site Football\n";

			dprint "Starting $site Basket\n";
			do_stoiximan_basket('https://www.stoiximan.gr/greek-coupon/Basketball-BASK',$verbose,$site);
			dprint "Done $site Basket\n";

	}

	case /1xbetcy|cy-1xbet/	{ 
			$par_tabs=0; # cannot do much more
			dprint "Starting $site Football\n";
			do1xbetcy_soccer('https://cy-1xbet.com/el/line/Football/' ,$verbose,$site); 
			dprint "Done $site Football\n";

			dprint "Starting $site Basket\n";
			do1xbetcy_basket('https://cy-1xbet.com/el/line/Basketball/' ,$verbose,$site); 
			dprint "Done $site Basket\n";
		}

	case "vistabet" {
			dprint "Starting $site soccer\n";
			do_sportingbet_soccer('https://www.vistabet.gr/t/sports/bet.aspx?' ,$verbose,$site); 
			dprint "Done\n";

			dprint "Starting $site Basket\n";
			do_sportingbet_basket('https://www.vistabet.gr/t/sports/bet.aspx?' ,$verbose,$site); 
			dprint "Done $site Basket\n";
		}

	case "sportingbet"	{ 
			dprint "Starting $site Football\n";
			do_sportingbet_soccer('https://www.sportingbet.gr/stoixima.aspx?' ,$verbose,$site); 
			dprint "Done $site Football\n";

			dprint "Starting $site Basket\n";
			do_sportingbet_basket('https://www.sportingbet.gr/stoixima.aspx?' ,$verbose,$site); 
			dprint "Done $site Basket\n";

		}

	case "mybet"	{ 
			dprint "Starting $site Football\n";
#			do_mybet_soccer('https://www.mybet.com/el/athlitika-stoiximata/programma-stoiximaton/' ,$verbose,$site); 
			do_mybet_soccer('https://www.mybet.com/el/athlitika-stoiximata/elliniko-kouponi/' ,$verbose,$site); 
			do_mybet_soccer('https://www.mybet.com/el/athlitika-stoiximata/semera/soccer/' ,$verbose,$site); 
			dprint "Done $site Football\n";
			dprint "Starting $site Basket\n";
			do_mybet_basket('https://www.mybet.com/el/athlitika-stoiximata/semera/basketball/' ,$verbose,$site); 
			dprint "Done $site BASKET\n";
		}

	case "bet365" {
			dprint "Starting $site soccer\n";
			do_bet365_soccer('https://mobile.bet365.gr/#type=Splash;key=1;ip=0;lng=20' ,$verbose,$site); 
#			do_bet365_euro('https://mobile.bet365.gr/' ,$verbose,$site); 
			dprint "Done $site Football\n";

			dprint "Starting $site Basket\n";
			do_bet365_basket('https://mobile.bet365.gr/#type=Splash;key=18;ip=0;lng=20' ,$verbose,$site); 
			dprint "Done $site BASKET\n";
	}
	case "novibet" {
			dprint "Starting $site soccer\n";
			do_novibet_soccer('https://www.novibet.com/el/sports/Soccer/1/' ,$verbose,$site); 
			dprint "Done $site Football\n";

			dprint "Starting $site Basket\n";
			do_novibet_basket('https://www.novibet.com/sports/Basketball/2' ,$verbose,$site); 
			dprint "Done $site BASKET\n";
	}

	case "goalbet" {
			dprint "Starting $site soccer\n";
			do_goalbet_soccer('https://www.goalbetint.com/index2.php?' ,$verbose,$site); 
			dprint "Done $site Football\n";

			dprint "Starting $site BASKET\n";
			do_goalbet_basket('https://www.goalbetint.com/index2.php?' ,$verbose,$site); 
			dprint "Done $site BASKET\n";
	}
	case "magicbet" {
			dprint "Starting $site soccer\n";
			do_magicbet_soccer('https://www.magicbet.gr/sports/coupon/day' ,$verbose,$site); 
			dprint "Done $site Football\n";

	}


	else { 
		print "\nI know nothing about $site\n"; 
		usage();
		exit(1); 
	}
}
vprint "Done $site completes successful RUN\n";

1;

######################################################################
#
# loose matching on week value for the same couponid because of
# various sites reporting games on different dates, forgetting to
# update etc. etc.
#
######################################################################
sub scoreupdate_by_couponid($$$$$$) {
my ($site,$couponid,$eventdate,$res,$scorehalf,$scorefull)=@_;

	$scorehalf	=~ s/-/:/g;
	$scorehalf	=~ s/^\s*//g;
	$scorehalf	=~ s/\s*$//g;

	$scorefull	=~ s/-/:/g;
	$scorefull	=~ s/^\s*//g;
	$scorefull	=~ s/\s*$//g;

	$couponid	=~ s/^\s*//g;
	$couponid	=~ s/\s*$//g;

	$eventdate	=~ s/^\s*//g;
	$eventdate	=~ s/\s*$//g;

	if ( !  looks_like_number(${couponid}) ) {
		vprint "COUPONID $couponid NAN";
		return;
	}
	my $dbh =getdbh();
	vprint "UPDATING couponid $couponid date $eventdate result $res score_half $scorehalf score_full $scorefull";
	# must update
	my $sql="update
				 bets 
			set 
				result		= trim('$res') ,
				score_half	= trim('$scorehalf'),
				score_full	= trim('$scorefull')
			where 
				site		= '$site'		and 
				couponid	= ${couponid}	and 
				week(eventdate)=week('${eventdate}'); ";

	dprint $sql."\n" if ($debug); 

	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my $rows=$sth->rows;
	vprint "MATCHED $rows rows, changed unknown";
	$sth->finish;
	$dbh->disconnect;
}

#
######################################################################
sub scoreupdate_by_opp2($$$$$$) {
my ($site,$opp2,$eventdate,$res,$scorehalf,$scorefull)=@_;

	$scorehalf	=~ s/-/:/g;
	$scorehalf	=~ s/^\s*//g;
	$scorehalf	=~ s/\s*$//g;

	$scorefull	=~ s/-/:/g;
	$scorefull	=~ s/^\s*//g;
	$scorefull	=~ s/\s*$//g;

	$eventdate	=~ s/^\s*//g;
	$eventdate	=~ s/\s*$//g;

	$opp2		=~ s/\'\'*//g;

	my $dbh = getdbh();

	# must update
	vprint "UPDATING opp2 $opp2 date $eventdate result $res score_half $scorehalf score_full $scorefull";
	my $sql="update
				 bets 
			set 
				result		= trim('$res') ,
				score_half	= trim('$scorehalf'),
				score_full	= trim('$scorefull')
			where 
				site		= '$site'	and 
				opp2		= '${opp2}'	and 
				week(eventdate)=week('${eventdate}'); ";

	dprint $sql."\n" if ($debug); 

	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my $rows=$sth->rows;
	vprint "MATCHED $rows rows, changed unknown";

	$sth->finish;
	$dbh->disconnect;
}

######################################################################
#
# Massage the actual data
#
######################################################################
sub domysql($$$$$$$$$){
my ($site,$evdate,$opp1,$opp2,$category,$market,$price,$decode,$couponid)=@_;
	my $sql;

	#normalize
	$evdate		=~ s/\s\s*/ /g;
	$evdate		=~ s/\'\'*//g;
	$opp1		=~ s/\'\'*//g;
	$opp2		=~ s/\'\'*//g;
	$market		=~ s/\'\'*//g;
	$category	=~ s/\'\'*//g;
	$price		=~ s/\'\'*//g;

	$evdate		=~ s/\./\//gi;
	# did we pick just the hour ? then we must add the date in front
    my $today=sprintf( "%02d/%02d/%4d",localtime->mday(), localtime->mon()+1,localtime->year() + 1900);
    if ( length($evdate) <= 5 ) {
           $evdate=$today . " " . $evdate;
    }

	$evdate		=~ s/\s+/ /gi; # one space
	# sample  valid date 	27/08/2016 16:30
	if ($evdate !~ /^\d{1,2}\/\d{2}\/\d{4}/) {
		vprint "BAD DATE $evdate";
    	return 0;
	}

	if ( ( ! looks_like_number($price) ) || (length($price)<=1) ) {
		vprint "NO/BAD PRICE on $evdate for $opp1 $opp2 $category $market price: $price \n" ;
		return;
	}

	$opp1		= trim($opp1);
	$opp2		= trim($opp2);
	$category	= trim($category);
	$market		= trim($market);
	$evdate		= trim($evdate);


	# UTF8 Greek is hell
	$opp1		=  myuc($opp1,$decode);
	$opp2		=  myuc($opp2,$decode);
	$market		=  myuc($market,$decode);
	$category	=  myuc($category,$decode);
	$market		=~ s/(\d)Ο/$1ο/g;
	$market		=~ s/(\d)ΗΣ/$1ης/g;

	$opp1 =~ s/ΤΟ 0% ΓΚΑΝΙΟΤΑ.*//g;
	$opp2 =~ s/ΤΟ 0% ΓΚΑΝΙΟΤΑ.*//g;

	foreach my $pattern (keys %OPP_TRANSLATIONS) {
			my $to=$OPP_TRANSLATIONS{$pattern};
			$opp1 =~ s/$pattern/$to/g;
			$opp2 =~ s/$pattern/$to/g;
	}

	# aaaaaargh
	$market		=~ s/ΑΝΤΕΡ/UNDER/gi;
	$market		=~ s/ΟΒΕΡ/OVER/gi;

	# greek to international numbers
	$market		=~ s/,/./gi;

	if ( ! looks_like_number($couponid)  ) {
		$couponid = "NULL";
	}
	if ( $market =~ /ΗΜΙΧΡΟΝ/g ) {
		vprint "MARKET not a good market $market ";
		return;
	}
	#
	# For certain markets we simply add some compatibility markets
	#
	if ( $site eq '1xbetcy' ) {
		#greek N1 N2
		if ($market =~ /^Ν(\d)$/ ) {
			$market=$1;
		}
		if ($market eq 'ΝΑ ΣΚΟΡΑΡΟΥΝ ΚΑΙ ΟΙ ΔΥΟ ΟΜΑΔΕΣ' ) {
			$market='GG';
		}
		if ($market eq 'ΝΑ ΣΚΟΡΑΡΟΥΝ ΚΑΙ ΟΙ ΔΥΟ ΟΜΑΔΕΣ - ΟΧΙ' ) {
			$market='NG';
		}

		#bad markets, no one else gives them
		if ( $market =~ /ΑΤΟΜΙΚΟ ΣΥΝΟΛΙΚΟ/g || $market =~ /INDIVIDUAL/ ) {
			vprint "MARKET not a good market $market ";
			return;
		}
	}

	# validate over under values	
	if ($market =~ /.*UNDER.*\((\d+\.\d+)\)/ ) {
		my $under=$1;
		if ( $under  !~ /\.5$/ ) {
			vprint "INVALID UNDER $under in MARKET $market";
			return;
		}
	}

#	novibet basket O/U are sometimes integer	(158.0)
	if ($market =~ /.*OVER.*\((\d+\.\d+)\)/ ) {
		my $over=$1;
		if ( $over !~ /\.5$/ ) {
			vprint "INVALID OVER $over in MARKET $market";
			return;
		}
	}


	# The actual SQL work ###
	# old fashioned linear
	if ($debug) {
		real_mysql($site,$evdate,$opp1,$opp2,$category,$market,$price,$couponid,undef);
	} else {
		# Multithreaded enqueue , dequeuer does all the work
		my $item= join('|',$site,$evdate,$opp1,$opp2,$category,$market,$price,$couponid);
		$sqlq->enqueue($item);
	}
}


######################################################################
#
#  This is the mailq sql dequeuer
#
######################################################################
sub deqsql {
	vprint "DEQUEUE SQL STARTED";

	my $dbh = getdbh() unless ($dryrun);
	

	while ( defined(my $item = $sqlq->dequeue() ) ) {
		vprint "DEQUEUEING $item";
		my ($site,$evdate,$opp1,$opp2,$category,$market,$price,$couponid)=split(/\|/,$item);
		real_mysql($site,$evdate,$opp1,$opp2,$category,$market,$price,$couponid,$dbh) unless ($dryrun);
	}
	$dbh->disconnect unless ($dryrun);
}

######################################################################
#
# As the name implies , the real work is taking place here
#
######################################################################
sub real_mysql($$$$$$$$$){
my ($site,$evdate,$opp1,$opp2,$category,$market,$price,$couponid,$dbh)=@_;

	if ( ! defined($dbh) ) {
		 $dbh = getdbh();
	}

	my $pricechange=0;
	my $samegame=" site	= '$site'	and
			eventdate	= STR_TO_DATE('$evdate','%d/%m/%Y') and
			opp1		= '$opp1'	and
			opp2 		= '$opp2'	and
			category	= '$category'	and 
			market		= '$market'";

	my $search = "select * from bets where ${samegame};"; 
	dprint $search;
	my $ssth = $dbh->prepare($search);
	$ssth->execute();
	my $rows=$ssth->rows;
	my $oldprice='';

	while (my $ref = $ssth->fetchrow_hashref()) {
  	  $oldprice=$ref->{'price'};
  	}
	$ssth->finish;

	# innodb updates are slow , so best we avoid them
	if ( ($rows >= 1) &&( $oldprice == $price) ) {
		dprint "NO PRICE CHANGE on $evdate for  $opp1 v $opp2, $market\n";
		return;
	}

	# recalculate over under only for globals
	my $under='NULL';
	my $over='NULL';
	if ($market =~ /^ΣΥΝΟΛΙΚΟ UNDER.*\((\d+\.\d+)\)/ ) {
		$under=$1;
	}
	if ($market =~ /^ΣΥΝΟΛΙΚΟ OVER.*\((\d+\.\d+)\)/ ) {
		$over=$1;
	}

	my $sql;
	if ($rows >= 1)  {
		vprint "UPDATING Price on $evdate for $opp1 v $opp2, $market, from:$oldprice to:$price\n";
		$pricechange=1;
		$sql="update bets set lastupdate=now(), price=$price,under=$under,over=$over where ${samegame};";
		dprint $sql;
	} else {
		vprint "INSERTING Price on $evdate for $opp1 v $opp2, $market, $price\n";
		$sql="insert into bets (
				site,
				lastupdate,
				evdate,
				eventdate,
				eventtime,
				eventwhen,
				opp1,
				opp2,
				category,
				market,
				price,
				under,
				over,
				couponid
			) values (
				'$site',
				now(),    
				trim('$evdate'),
				STR_TO_DATE('$evdate','%d/%m/%Y'), 
				time(substring('$evdate' from locate(' ','$evdate')+1)),
				STR_TO_DATE('$evdate','%d/%m/%Y %H:%i'), 
				trim('$opp1'),
				trim('$opp2'),
				trim('$category'),
				trim('$market'),
				$price,
				$under,
				$over,
				$couponid );";
	}
	dprint $sql . "\n";

	my $sth = $dbh->prepare($sql);
	$sth->execute();
	$sth->finish;

#	# if we  have  bad dates , enable this
#	$sql='update bets set eventwhen=concat(concat(eventdate, " "),eventtime) where eventwhen is null;';
#	dprint $sql . "\n";
#	$sth = $dbh->prepare($sql);
#	$sth->execute();
#	$sth->finish;

	# insert an entry in the changes tables
	if ( $oldprice eq '' ) {
			$oldprice = 'NULL';
	}
	if ( ($pricechange==1 ) && ($oldprice ne 'NULL' ) && ($price ne 'NULL') )  {
		$sql="insert into changes (	
					site, lastupdate,
					evdate, eventdate,
					eventtime,
					eventwhen,
					opp1, opp2,    
					category, market, price_from, price_to, couponid
			) values ( 
					'$site',  now(),    
					trim('$evdate'), STR_TO_DATE('$evdate','%d/%m/%Y'), 
					time(substring('$evdate' from locate(' ','$evdate')+1)),
					STR_TO_DATE('$evdate','%d/%m/%Y %H:%i'), 
					trim('$opp1'), trim('$opp2'), 
					trim('$category'), trim('$market'), $oldprice, $price, $couponid);";
			
		dprint $sql . "\n";

		my $sth = $dbh->prepare($sql);
		$sth->execute();
		$sth->finish;

	}
}


######################################################################
# Print each row in an HTML table
######################################################################
sub getrows($$) {
	my ($ts,$verbose)=@_;
	foreach my $row ($ts->rows) {
		foreach my $elem (@$row) {
			$elem =~ s/^ [ ]*//g;
			$elem =~ s/^\s\s*//g;
			$elem =~ s/ [ ]*$//g;
			$elem =~ s/\s\s*$//g;
			$elem =~ s/\s\s*/ /g;
			vprint $elem."|" if ($verbose);
		}
	}
}


######################################################################
#
# If there are HTML <table> entries, this dumps them
#
######################################################################
sub gettables($) {
my ($html)=@_;

	 my $te=HTML::TableExtract->new();
	 $te->parse($html);

	 # Examine all matching tables
	 foreach my $ts ($te->tables) 	{
	 	vprint "Table (". join(',', $ts->coords) . "):\n" if ( $verbose);
		getrows($ts,$verbose);
	}
}


######################################################################
#
# Auxiliary for testing, read html from file
#
######################################################################
sub read_data($) {
my ($file)=@_;
my $html=""	;
	open(FIN,"<" .$file);
	while(<FIN>) {
		$html .= $_;
	}
	close(FIN);
	return $html;
}

######################################################################
#
# UTF-8 greek uppercasing
#
######################################################################
sub myuc($$){
my ($str,$decode)=@_;

	my $enc="utf-8";
	my $text_str=$str;

	# Just in case
	$text_str = uc $text_str;

	$text_str =~ s/ά/α/g;
	$text_str =~ s/έ/ε/g;
	$text_str =~ s/ί/ι/g;
	$text_str =~ s/ϊ/ι/g;
	$text_str =~ s/ϋ/υ/g;
	$text_str =~ s/ύ/υ/g;
	$text_str =~ s/ή/η/g;
	$text_str =~ s/ό/ο/g;
	$text_str =~ s/ώ/ω/g;
	
	$text_str =~ s/Ά/Α/g;
	$text_str =~ s/Έ/Ε/g;
	$text_str =~ s/Ί/Ι/g;
	$text_str =~ s/Ϊ/Ι/g;
	$text_str =~ s/Ϊ́/Ι/g;
	$text_str =~ s/Ϋ/Υ/g;
	$text_str =~ s/Ύ/Υ/g;
	$text_str =~ s/Ή/Η/g;
	$text_str =~ s/Ό/Ο/g;
	$text_str =~ s/Ώ/Ω/g;

	# make sure you use the default el-gr-utf8 locale
	my $candecode=1;
	eval { 
		decode($enc, $text_str); 
	}; 
	if ($@) {
		$candecode=0;
	}

	if ( $decode && $candecode ) {
		$text_str = decode($enc, $text_str);
	}

	$text_str = uc $text_str;

	$text_str =~ s/ά/α/g;
	$text_str =~ s/έ/ε/g;
	$text_str =~ s/ί/ι/g;
	$text_str =~ s/ϊ/ι/g;
	$text_str =~ s/ϋ/υ/g;
	$text_str =~ s/ύ/υ/g;
	$text_str =~ s/ή/η/g;
	$text_str =~ s/ό/ο/g;
	$text_str =~ s/ώ/ω/g;
	
	$text_str =~ s/Ά/Α/g;
	$text_str =~ s/Έ/Ε/g;
	$text_str =~ s/Ί/Ι/g;
	$text_str =~ s/Ϊ/Ι/g;
	$text_str =~ s/Ϋ/Υ/g;
	$text_str =~ s/Ύ/Υ/g;
	$text_str =~ s/Ή/Η/g;
	$text_str =~ s/Ό/Ο/g;
	$text_str =~ s/Ώ/Ω/g;

	if ( $decode && $candecode ) {
		$text_str = encode($enc, $text_str);
	}
	return($text_str);
}


######################################################################
#
# Verbose print
#
######################################################################
sub vprint($) {
	my ($what) = @_;
	chomp($what);
	my $tid=threads->self->tid();
	if ( $nosyslog ) {
		print "[" . now() . "] [$site:$tid] ". $what . "\n"  if ( $verbose );
	} else {
		my $message="[$site:$tid] ". $what ;
		$message =~ s/\t//g;
		$message =~ s/\s\s*/ /g;
		$message =~ s///g;
		syslog("info|local0", $message) if ($verbose);
	}
}

######################################################################
#
# Verbose print too!
#
######################################################################
sub dprint($) {
	my ($what) = @_;
	chomp($what);
	my $tid=threads->self->tid();
	if ( $nosyslog ) {
		print "[" . now() . "] [$site:$tid] " . $what . "\n" if ( $debug );
	} else {
		my $message="[$site:$tid] ". $what ;
		$message =~ s/\t//g;
		$message =~ s/\s\s*/ /g;
		$message =~ s///g;
		syslog("debug|local0", $message) if ($debug);
	}
}
######################################################################
sub now() {
	 return sprintf( "%02d/%02d/%4d %02d:%02d",
			localtime->mday(),
			localtime->mon()+1,
			localtime->year() + 1900,
			localtime->hour(),
			localtime->min());
}



######################################################################
# This is the generic parallel executor
# Params: 	Reference to scraping function
#			category
#			site
#			reference to games hash
#				games hash must be %games{$game}{'href'} %games{$game}{'date'}
#				where game="$opp1 v $opp2 "
# 	if date can be gotten from called function it could contain a time
#
# ALL functions called from here must follow this signature
# scrape_function($game,$evdate,$href,$category,$site);
#
######################################################################
sub par_do_forked($$$$) {
	my ($func,$category,$site,$gamesref)=@_;
	# dereffernce games hash
	my %games = %$gamesref;
    #Now fetch each game in parallel
    my $count=0;
	my $game;
	my $href;
	my $evdate;
	vprint "********************************************";
	vprint "**    ENTERING PARALLEL OPERATION";
	vprint "**    SITE $site SPORT $category";
	vprint "********************************************";
	my $numgames=scalar keys %games;
	vprint "NUMBER OF GAMES=$numgames TABS=$par_tabs";
	return if ($numgames<=0);
	my $gamenum=0;
    foreach my $key (shuffle(keys(%games))) {
		$gamenum++;
		vprint "GAME NUMBER: $gamenum OF $numgames GAME $key";
		if ( $site eq 'opap' ) {
			$game	= "";	# cannot be gotten for opap
        	$href	= $key;
        	$evdate	= $games{$href};
		} else {
			$game	= $key;
        	$href	= $games{$key}{'href'};
        	$evdate	= $games{$key}{'date'};
		}
        # do it in batches of $par_tabs
        if ( $count < ($par_tabs - 1) ) {
            $count++;
            my $pid = fork();
            if( $pid == 0 ){
				$func->($game,$evdate,$href,$category,$site);
                exit 0;
            }
        } else {
            $func->($game,$evdate,$href,$category,$site);
            $count=0;

			# pick up the kids above
            my $kid=undef;
            do {
                $kid = waitpid(-1, WNOHANG);
            } while $kid > 0;
        }
    }
	vprint "SLEEPY";
	sleep 13;
    # catch the remaining ones
    my $kid=undef;
    do {
        $kid = waitpid(-1, WNOHANG);
    } while $kid > 0;

}

######################################################################
#
# Parallel Threaded execution, one thread per additional firefox TAB
#
######################################################################
sub par_do_threaded($$$$) {
	my ($func,$category,$site,$gamesref)=@_;
	# dereffernce games hash
	my %games = %$gamesref;
    #Now fetch each game in parallel
    my $count=0;
	my $game;
	my $href;
	my $evdate;
	vprint "********************************************";
	vprint "**    ENTERING PARALLEL OPERATION";
	vprint "**    SITE $site SPORT $category";
	vprint "********************************************";
	my $numgames=scalar keys %games;
	vprint "NUMBER OF GAMES=$numgames TABS=$par_tabs";
	return if ($numgames<=0);
	my $gamenum=0;
    foreach my $key (shuffle(keys(%games))) {
		$gamenum++;
		vprint "GAME NUMBER: $gamenum OF $numgames GAME $key";
		if ( $site eq 'opap' ) {
			$game	= "";	# cannot be gotten for opap
        	$href	= $key;
        	$evdate	= $games{$href};
		} else {
			$game	= $key;
        	$href	= $games{$key}{'href'};
        	$evdate	= $games{$key}{'date'};
		}
        # do it in batches of $par_tabs
        if ( $count < ($par_tabs - 1) ) {
            $count++;
			my $tid=threads->create($func,$game,$evdate,$href,$category,$site)->detach();
			vprint "THREAD $tid created\n";
        } else {
			# This is the linear execution part of the code
            $func->($game,$evdate,$href,$category,$site);
            $count=0;
        }
    }
}

######################################################################
# pick a parallel engine
######################################################################
sub par_do($$$$) {
	my ($func,$category,$site,$gamesref)=@_;

	if ($threaded) {
		par_do_threaded($func,$category,$site,$gamesref);
	} else { 
		par_do_forked($func,$category,$site,$gamesref);
	}
}

######################################################################
#
# Get a new handler from mozrepl
#
######################################################################
sub newFirefox {
	# this little tidbit is for the telnet client to mozrepl proper
	$ENV{'MOZREPL_TIMEOUT'}=$TIMEOUT+5;
	my $firefox=WWW::Mechanize::Firefox->new( 
					timeout		=> $TIMEOUT,
					activate	=> 1,
					autoclose	=> !$dev,
					frames		=> 1,
					subframes	=> 1,
					create		=> 1
				);

	$firefox->allow( javascript => 1 );

	return($firefox);
}


#######################################################################
##
## Get a new handler from phantomJS
##
#######################################################################
#sub newMech {
#	my $mech = WWW::Mechanize::PhantomJS->new(
#      autodie => 0, # make HTTP errors non-fatal
#      port => 8910,
#      log => 'WARN',
#	  agent =>   'Mozilla/5.0 (Windows; U; Windows NT 6.1; nl; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13',
#      launch_arg => [ 
#				'--webdriver=8910', 
#				'--ignore-ssl-errors=true' ,
#	  			'--agent="Mozilla/5.0 (Windows; U; Windows NT 6.1; nl; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13"', ],
#	);
#
#	return $mech
#}
#
#
#######################################################################
##
## PNG dump a web page
##
#######################################################################
#sub dump_screen($) {
#	my ($mech)=@_;
#    my $page_png = $mech->content_as_png();
#
#    my $fn= "/tmp/screen.png";
#    open my $fh, '>', $fn
#        or die "Couldn't create '$fn': $!";
#    binmode $fh, ':raw';
#    print $fh $page_png;
#    close $fh;
#};

######################################################################
# remove leading trailing spaces
######################################################################
sub trim($) {
	my ($str)=@_;
	$str =~ s/^\s\s*//g;
	$str =~ s/\s\s*$//g;

return($str);
}

######################################################################
# connect to db;
######################################################################
sub getdbh{
	my $dbh = DBI->connect(	"DBI:mysql:database=$database;host=$dbhost", 
			$dbuser,
			$dbpassword,
			{'RaiseError' => 1, 'mysql_enable_utf8' => 1 }
	 	);
	die 'No DB connection' if ( ! $dbh);

	my $sql="SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	$sth->finish;

	return($dbh);
}

######################################################################
#
# timed $firefox->get()  (experimental)
#
######################################################################
sub timed_get($$) {
	my($firefox,$url)=@_;
	my $response=undef;
	vprint "TIMED GET $url";
	eval { 
    	local $SIG{ALRM} = sub { die "alarm timeout" };
    	alarm $TIMEOUT;                   # schedule alarm in 10 seconds 
		$response=$firefox->get($url);
    	alarm 0;                    # cancel the alarm
	};
	if ($@ !~ /alarm timeout/) {
		vprint "TIMEOUT stopping page load";
		$firefox->eval('window.stop();');
	}
	return($response);
}


######################################################################
#
#   Lusers beware
#
######################################################################
sub usage() {
print "
USAGE:

scrape --site=TARGET [--tabs=<parallel-tabs>] [--verbose] [--debug] [--dryrun]  [--timeout=seconds] [--nosyslog]
scrape --site=betonewsold --pastdays=<how many days of historic data> [--verbose] [--debug] [--dryrun] [--timeout=seconds] [--nosyslog]

WARNING: betonews and opap are interchangeable, betonews is used for time travel
WARNING: verbose is really verbose, debug not so much
WARNING: during dryrun no SQL work will be done

Options:verbose -- prints a lot of info
	debug	-- echoes SQL statements
	dryrun	-- skips SQL execution, good for testing new stuff
	timeout -- page load timeout
	nosyslog-- log to the terminal

Available Targets:
	1xbetcy|cy-1xbet
	opap
	mybet
	bet365
	betonews
	stoiximan
	sportingbet
	vistabet	(same as above)
	betcosmos (for game results only)
	novibet
	goalbet
	magicbet

Author: Angelos Karageorgiou (angelos\@unix.gr)
";
	exit(0);
}



######################################################################
#
# This is the end of the code as we know it
#
######################################################################
END {
	# pick up any strayed children
	my $kid=undef;
	do {
		$kid = waitpid(-1, WNOHANG);
	} while $kid > 0;

	# this signals the sql thread to exit
	undef $sqlq;
}



