#!/usr/bin/perl

######################################################################
#
#    1xbetcy scraping
#
######################################################################

use strict;
use utf8;
use Mojo::DOM;

sub scrape_1xbetcy_per_game($$$$$);
sub do1xbetcy_find_games($$$);
sub vprint($);
sub trim($);

# globals, careful when threading
# thread global
my %games;
my $baseURL="https://cy-1xbet.com/el";


######################################################################
#
# FootBall scraping
#
######################################################################
sub  do1xbetcy_soccer($$$) {
my ($url,$verbose,$site) = @_;

	my $category = "SOCCER";
	my $firefox = newFirefox();

	vprint "URL $url";
	my $response= $firefox->get($url);

	# ease the strain on firefox, get rid of the original window
	my $html=$firefox->content;
#	undef $firefox;
	do1xbetcy_find_games($site,$category,$html);
}


######################################################################
#
# BasketBall scraping
#
######################################################################
sub  do1xbetcy_basket($$$) {
my ($url,$verbose,$site) = @_;

	my $category = "BASKET";
	my $firefox = newFirefox();

	vprint "URL $url";
	my $response=$firefox->get($url);

	# ease the strain on firefox, get rid of the original window
	my $html=$firefox->content;
#	undef $firefox;
	do1xbetcy_find_games($site,$category,$html);
}


######################################################################
#
# main page scraping
#
######################################################################
sub  do1xbetcy_find_games($$$) {
my ($site,$category,$html) = @_;

	vprint "MOJO work\n";
	my $dom=Mojo::DOM->new($html);
	for my $div ($dom->find('div.line')->each) {
		my $game="";
		my $market="";
		my $price="";
		my $opp1="";
		my $opp2="";
		my $date="";
		my $evdate=undef;
	
		for my $span ($div->find('span.n')->each) {
			vprint "GAME:"  . $span->{title};
			($opp1,$opp2)=split(' — ',$span->{title});
		}
		# clean up garbage
		$opp2=~ s/ \(Περιλαμβάνει Παράταση\)//g;
		$opp2=~ s/  \. \(2 HALVES OF 40 MIN\)//g;

		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";

		for my $xdate ($div->find('div.date\ min')->each) {
			for my $span ($xdate->find('span')->each) {
				my $text=$span->text;
				vprint "TEXT $text";
				my $date=$text;
				$date=~ s/\./\//gm;
				my $year=localtime->year()+1900;
				if ( $date =~ /\d\{2}\/\d{2}\s\d{2}.*/) {
					$date =~ s/ /\/$year /;
				} else {
					$date .= "/$year";
				}
				$evdate=trim($date);
				
				vprint "DATE $evdate";

				my @lines=split('\\n',$span);
				my $time=$lines[2];
				$time =~ s/<\/.*$//gm;
				$time =~ s/^.*>//gm;
				vprint "TIME $time";

				$evdate .= ' ' . trim($time);
			}
		}
		vprint "EVDATE $evdate";
		$games{"$opp1 v $opp2"}{'date'}=$evdate;

		for my $name ($div->find('a.name\ nameInLine')->each ) { 
			my $x= $name->{href}; 
			vprint "HREF: $x";
			$games{"$opp1 v $opp2"}{'href'}=$baseURL."/".$x;
			last;
		}
	}
	par_do(\&scrape_1xbetcy_per_game,$category,$site,\%games);
}

######################################################################
#
# Scrape each game
#
######################################################################
sub scrape_1xbetcy_per_game($$$$$){
my ($game,$evdate,$url,$category,$site) = @_;

    my $market="";
    my $price="";
    my ($opp1,$opp2)    = split(/ v /,$game);

	if ( ($category eq "BASKET" && $url !~ /Basketball/gi) ||
		 ($category eq "SOCCER" && $url !~ /Football/gi) ) {
		vprint "WRONG SPORT: GAME $game is not $category";
		return;
	}

	vprint "SCRAPING GAME $game DATE $evdate";
    my $firefox = newFirefox();
    vprint "URL:$url\n";
	my $response=$firefox->get($url);

	vprint "MOJO work";
    my $dom = Mojo::DOM->new($firefox->content);

	for my $top ($dom->find('div.bet_group_col')->each) {
		# thread local
		my %seenmarkets;
		for my $div ($top->find('div.bets')->each) {
			my @prices=undef;
			my @markets=undef;
			my $i=0;
			for my $span ($div->find('span.bet_type')->each) {
				my $market=$span->text;
				if ( $market =~ /Συνολικό όβερ/ ) {
					$market=~ s/Συνολικό όβερ/ΣΥΝΟΛΙΚΟ OVER/gi;
				} elsif ($market =~  /Συνολικό άντερ/) {
					$market=~ s/Συνολικό άντερ/ΣΥΝΟΛΙΚΟ UNDER/gi;
				}
				$market=myuc($market,1);
				if (exists($seenmarkets{$market})) {	
					vprint "MARKET $market already processed, exiting"; # catch all non full-time markets
					return;
				}
				$markets[$i]=$market;
				$i++;
			}
			my $price=undef;
			$i=0;
			for my $kspan ($div->find('span.koeff')->each) {
				$kspan =~ /<i>(\d[\d]*\.\d[\d]*)<\/i>/gm;
				$price=$1;
				if ( $price eq "" ) {
					$kspan =~ /(\d[\d]*\.\d[\d]*)/gm;
					$price=$1;
				}
				my $market=$markets[$i];
				vprint "GAME $opp1 v $opp2 MARKET $market PRICE $price" ;
				$prices[$i]=$price;
				$i++;
			}
			# all the market / price pairs are now here
			for (my $j=0;$j<$i;$j++) {
				domysql($site,$evdate,$opp1,$opp2,$category,$markets[$j],$prices[$j],1,"-");
				$seenmarkets{$markets[$j]}=1;
			}
		}
	}
}


1;
