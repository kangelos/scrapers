#!/usr/bin/perl

###############################################################################
# Odds scraping program, Angelos Karageorgiou <angelos@unix.gr>
#
# Please note that the code for this project has evolved in many steps
# As procs were added the code became more intelligent
# eventually it will grow up to be object oriented
#
##############################################################################

#
#
# Notes to self
# novibet and goalbet must have all the bets not just the top page ones
#
#

require 'utf8_heavy.pl';
use strict;
use utf8;
use threads;
use POSIX ":sys_wait_h";
use Thread::Queue;
use Sys::Syslog; 
use Getopt::Long;
use Switch;

sub usage();
sub vprint($);
sub dprint($);
sub end;
sub deqsql;

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
#require 'magicbet.pl';
require 'betshop.pl';
require 'bwin.pl';



######################################################################
# global vars;
######################################################################
our $verbose	=0;		# a lot of detail
our $debug	=0;		# dumps SQL details
our $site	="";
our $par_tabs=0;		# number of tabs in parallel
our $pastdays=7;		# how many days in the past to fetch data
our $TIMEOUT=450;	# seconds
our $dryrun=0;		# no DB work
our $nosyslog=0;		# console output
our $dev=0;			# development mode

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
our $sqlq = Thread::Queue->new();    # A new empty queue
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
			do_novibet_soccer('https://www.novibet.com/el/sports/Soccer/1/' ,$site); 
			dprint "Done $site Soccer\n";

			dprint "Starting $site Basket\n";
			do_novibet_basket('https://www.novibet.com/el/sports/Basketball/2' ,$site); 
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
# same as betshop
#	case "magicbet" {
#			dprint "Starting $site soccer\n";
#			do_magicbet_soccer('https://www.magicbet.gr/sports/coupon/week' ,$verbose,$site); 
#			dprint "Done $site Football\n";
#
#	}
	case "betshop" {
			dprint "Starting $site BASKET\n";
			do_betshop_basket('https://www.betshop.gr/sports/game/2' ,$verbose,$site); 
			dprint "Done $site BASKETBALL\n";

			dprint "Starting $site soccer\n";
			do_betshop_soccer('https://www.betshop.gr/sports/game/1' ,$verbose,$site); 
			dprint "Done $site Football\n";
	}
	case "bwin" {
			dprint "Starting $site SOCCER\n";
			do_bwin_soccer('https://sports.bwin.gr/el/sports#sportId=4' ,$verbose,$site); 
			dprint "Done $site BASKETBALL\n";
	}

	else { 
		print "\nI know nothing about $site\n"; 
		usage();
		exit(1); 
	}
}
end();
vprint "Done $site completes successful RUN\n";




######################################################################
#
#   Lusers beware
#
######################################################################
sub usage() {

	print << 'INS';

USAGE:

scrape --site=TARGET [--tabs=<parallel-tabs>] [--verbose] [--debug] [--dryrun]  [--timeout=seconds] [--nosyslog]

WARNING: betcosmos is used for time travel
WARNING: verbose is really verbose, debug not so much
WARNING: during dryrun no SQL work will be done

Options:
	verbose  - prints a lot of info
	debug	 - echoes SQL statements
	dryrun	 - skips SQL execution, good for testing new stuff
	timeout  - page load timeout
	nosyslog - log to the terminal

Available Targets:
	1xbetcy|cy-1xbet
	opap
	mybet
	bet365
	betonews
	stoiximan
	sportingbet|vistabet	(same shit)
	betcosmos	(for game results only)
	novibet
	goalbet
	betshop
	bwin

Author: Angelos Karageorgiou (angelos@unix.gr) 

INS


exit(0);
}



######################################################################
#
# This is the end of the code as we know it
#
######################################################################
sub end {
	# wait while there are items in the SQLQ 
	my $item=$sqlq->peek();
	my $attempts=0;
	while ($item && ($attempts < 10) ) {
		vprint "DATA Still in the Queue $item";
		sleep(1);
		$item = $sqlq->peek(0);
		$attempts++;
	}

	# this signals the sql thread to exit
	undef $sqlq;

	#if threaded
	sleep 1 while threads->list();

	# if forked
	# pick up any strayed children
	my $kid=undef;
	do {
		$kid = waitpid(-1, WNOHANG);
	} while $kid > 0;


}


