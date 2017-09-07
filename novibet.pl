#!/usr/bin/perl

use strict;
use utf8;
use Switch;
use Mojo::DOM;
use Time::localtime;


sub novibet_scrape_top_page($$$$);
sub novibet_scrape_over_under($$$$);
sub novibet_scrape_gg_ng($$$);
sub novibet_change_market($$$);
sub novibet_mojo_soccer($$$);
sub vprint($);
sub novibet_date($);


#
# Aug 31 2016, one page scraping only
#

######################################################################
#
# FootBall scraping
#
######################################################################
sub  do_novibet_soccer($$) {
my ($url,$site) = @_;

	my $category = "SOCCER";
	my $firefox = newFirefox();
	my $response=$firefox->get($url);
	my $html=$firefox->content();

	foreach my $selector ( $firefox->selector('div')) {
        my $sid = $selector->{id};
        my $inner = $selector->{innerHTML};
        if ( $inner =~ /^\d{2,}$/ ) {
			vprint "DIV " . $sid . " " .$inner;	
			$firefox->click({dom=>$selector,synchronize=>0});
			sleep(3);
			novibet_mojo_soccer($site,$category,$firefox->content());
        }
    }
}

######################################################################
#
# Basket scraping
#
######################################################################
sub  do_novibet_basket($$$) {
	my ($url,$site) = @_;
	my $category = "BASKET";
	my $firefox = newFirefox();
	my $response=$firefox->get($url);
	my $html=$firefox->content();

	foreach my $selector ( $firefox->selector('div')) {
        my $sid = $selector->{id};
        my $inner = $selector->{innerHTML};
        if ( $inner =~ /^\d{2,}$/ ) {
			vprint "DIV " . $sid . " " .$inner;	
			$firefox->click({dom=>$selector,synchronize=>0});
			sleep(3);
			novibet_mojo_basket($site,$category,$firefox->content());
        }
    }
}

######################################################################
sub novibet_mojo_soccer($$$){
	my ($site,$category,$html)=@_;
	
    my $game="";
    my $market="";
    my $price="";
    my $opp1="";
    my $opp2="";
    my $date="";
    my $time="";
    my $evdate="";
    my %games=undef;
	my $evtime="";
	my $couponid="";

    vprint "MOJO work\n";
	vprint "---------------MOJO----------";

    my $dom=Mojo::DOM->new($html);


    for my $divmain ($dom->find('div.main\ marketviews_secondary\ col-xs-4\ col-full-height')->each) {
		for my $compdiv ($divmain->find('div.competition')->each) {
			for my $timespan ($compdiv->find('span')->each) {
				$evtime=$timespan->text;
				vprint "EVTIME $evtime\n";
			}
		}
		$evdate=novibet_date($evtime);
		vprint "EVDATE $evdate";
		next if ( ! defined ($evdate));

		for my $divinfo ($divmain->find('div.event_info')->each) {
			$game=$divinfo->text;
			vprint "GAME $game";
		}
		vprint "GAME $game EVTIME $evtime";
		($opp1,$opp2)=split(/-/,$game);
		$opp1=trim($opp1);
		$opp2=trim($opp2);
		
		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";

		for my $div ($divmain->find('div.market_group\ event_markets')->each) {
			my $topmarket="";
			for my $h3 ($div->find('h3')->each) {
				$market=$h3->text;
			}
			$topmarket=$market;
			for my $bdiv ($div->find('div.bet')->each) {
				$market=$bdiv->text;
				for my $span ($bdiv->find('span.odd')->each) {
					$price=$span->text;
				}
				vprint "TOPMARKET $topmarket MARKET $market PRICE $price";

				if ($topmarket eq 'Αποτέλεσμα Αγώνα') {
					if ( $market eq $opp1 ) {
						$market="1";
					} elsif ( $market eq $opp2 ) {
						$market="2";
					} else {
						$market="X";
					}
					vprint "CALCULATED MARKET $market PRICE $price";
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
					next;
				}


				if ($topmarket eq 'Θα σκοράρουν και οι δύο ομάδες στον Αγώνα') {
					if ($market eq "Όχι" ) {
						$market="NG";
					} else {
						$market="GG";
					}
					vprint "CALCULATED MARKET $market PRICE $price";
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
					next;
				}
				# greek Xes
				if ($topmarket eq 'Διπλή Ευκαιρία') {
					if ( $market eq "1X" ) {
						$market="1Χ";
					}
					if ( $market eq "X2" ) {
						$market="Χ2";
					}
					vprint "CALCULATED MARKET $market PRICE $price";
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
					next;
				}

				if ($topmarket eq 'Αγορές Γκολ Αγώνα') {
					if ($market =~ /Under/ ) {
						my $temp=$market;
						$market=~ m/Under (\d+,\d+)/;
						my $ouval= $1;
						$ouval =~ s/,/\./g;
						$market="ΣΥΝΟΛΙΚΟ UNDER ($ouval)";
					}
					if ($market =~ /Over/ ) {
						my $temp=$market;
						$market=~ m/Over (\d+,\d+)/;
						my $ouval= $1;
						$ouval =~ s/,/\./g;
						$market="ΣΥΝΟΛΙΚΟ OVER ($ouval)";
					}
					vprint "CALCULATED MARKET $market PRICE $price";
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
					next;
				}
			} #bet
		}  # market_group
	} # second column
}


######################################################################
sub novibet_mojo_basket($$$){
	my ($site,$category,$html)=@_;
	
    my $game="";
    my $market="";
    my $price="";
    my $opp1="";
    my $opp2="";
    my $date="";
    my $time="";
    my $evdate="";
    my %games=undef;
	my $evtime="";
	my $couponid="";

    vprint "MOJO work\n";
	vprint "---------------MOJO----------";

    my $dom=Mojo::DOM->new($html);


    for my $divmain ($dom->find('div.main\ marketviews_secondary\ col-xs-4\ col-full-height')->each) {
		for my $compdiv ($divmain->find('div.competition')->each) {
			for my $timespan ($compdiv->find('span')->each) {
				$evtime=$timespan->text;
				vprint "EVTIME $evtime\n";
			}
		}
		$evdate=novibet_date($evtime);
		vprint "EVDATE $evdate";
		next if ( ! defined ($evdate));

		for my $divinfo ($divmain->find('div.event_info')->each) {
			$game=$divinfo->text;
			vprint "GAME $game";
		}
		vprint "GAME $game EVTIME $evtime";
		($opp1,$opp2)=split(/-/,$game);
		$opp1=trim($opp1);
		$opp2=trim($opp2);
		
		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";

		for my $div ($divmain->find('div.market_group\ event_markets')->each) {
			my $topmarket="";
			for my $h3 ($div->find('h3')->each) {
				$market=$h3->text;
			}
			$topmarket=$market;
			for my $bdiv ($div->find('div.bet')->each) {
				$market=$bdiv->text;
				for my $span ($bdiv->find('span.odd')->each) {
					$price=$span->text;
				}
				vprint "TOPMARKET $topmarket MARKET $market PRICE $price";

				if ($topmarket =~ /^Νικητής Αγώνα /) {
					if ( $market eq $opp1 ) {
						$market="1";
					} elsif ( $market eq $opp2 ) {
						$market="2";
					} 
					vprint "CALCULATED MARKET $market PRICE $price";
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
					next;
				}

				if ($topmarket =~ /^Πόντοι Αγώνα \(([0-9][0-9]*,[0-9][0-9]*)\)/) {
					my $ouval=$1;
					$ouval =~ s/,/\./g;
					if ($market =~ /^Under \([0-9][0-9]*,[0-9][0-9]*\)/ ) {
						$market="ΣΥΝΟΛΙΚΟ UNDER ($ouval)";
					}
					if ($market =~ /^Over \([0-9][0-9]*,[0-9][0-9]*\)/ ) {
						$market="ΣΥΝΟΛΙΚΟ OVER ($ouval)";
					}
					vprint "CALCULATED MARKET $market PRICE $price";
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
					next;
				}
			} #bet
		}  # market_group
	} # second column
}

######################################################################
sub novibet_date($) {
my ($evtime)=@_;

my %MONTHS= (
    'Ιαν'	=> '01',
    'Φεβ'	=> '02',
    'Μαρ'   => '03',
    'Απρ'   => '04',
    'Μαι'   => '05',
    'Ιουν'  => '06',
    'Ιουλ'  => '07',
    'Αυγ'   => '08',
    'Σεπ'   => '09',
    'Οκτ'   => '10',
    'Νοε'   => '11',
    'Δεκ'   => '12'
);

	my @dateparts=split(/ /,$evtime);
	vprint "LASTEL:".$#dateparts;

	if ($#dateparts==2) {
		my $mday=$dateparts[0];
		my $mon=$MONTHS{$dateparts[1]};
		my $evtime=$dateparts[2];
		my $evdate=sprintf( "%02d/%02d/%4d %s",$mday,$mon,localtime->year()+1900,$evtime);
		return($evdate);
	}

	# calculate the proper time. Work needed if daynames appear in here	
	if ( $evtime =~ /σε (\d+)/ ) {
		my $extramins=$1;
		my $nowhour=sprintf("%02d:%02d", localtime->hour(), localtime->min());
		my $newmin= localtime->min()+$extramins;
		my $modmins= $newmin % 60;
		my $newhour= localtime->hour();
		if ( $modmins != $newmin) {
			$newhour++;
		}
		$evtime=sprintf("%02d:%02d", $newhour,$modmins);
		my $evdate=sprintf( "%02d/%02d/%4d %s",localtime->mday(), localtime->mon()+1,localtime->year() + 1900,$evtime);
		return($evdate);
	}

	if ( $evtime =~ /^\d\d:\d\d$/ ) {
		my $evdate=sprintf( "%02d/%02d/%4d %s",localtime->mday(), localtime->mon()+1,localtime->year() + 1900,$evtime);
		return($evdate);
	}
	return (undef);
}

1;
