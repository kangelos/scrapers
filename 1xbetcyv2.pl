#!/usr/bin/perl

use strict;
use utf8;
use Scalar::Util qw(looks_like_number);
use Mojo::DOM;

our $debug;
my @validOU=( 0.5, 1, 1.5, 2, 2.5,  3, 3.5, 4, 4.5, 5, 5.5 ,6);


sub vprint($);

######################################################################
#
# FootBall scraping
#
######################################################################
sub  do1xbetcy_soccer($$$) {
my ($url,$verbose,$site) = @_;

	my $category = "SOCCER";
	my $firefox = newFirefox();

	my $response=$firefox->get($url);
	sleep(2);

	vprint "MOJO work\n";

	my $dom=Mojo::DOM->new($firefox->content);
		my $game="";
		my $market="";
		my $price="";
		my $opp1="";
		my $opp2="";
		my $date="";
		my $time="";
		my $evdate="";

	my %dates;
	my %gameurls;

	for my $div ($dom->find('div.line')->each) {
		vprint "-------------------------------";
		for my $span ($div->find('span.n')->each) {
			vprint "GAME:"  . $span->{title};
			($opp1,$opp2)=split(' — ',$span->{title});
		}
		$opp2=~ s/\(.*\)//g;
		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";

		my $dave=$/;
		undef $/;
		for my $date ($div->find('div.date\ min')->each) {
			for (my $i=1; $i<=5;$i++ ) {
				$date=~ s/<.*?>//gm;
			}
			my @lines=split(/\n/,$date);
			$date=$lines[3];
			$date=~ s/^\s*//g;
			$date=~ s/\s*$//g;
			$date=~ s/^\"\>//gm;
			$date=~ s/\./\//gm;
			my $year=localtime->year()+1900;
			$date=~ s/ /\/$year /;
			vprint "-------------------------------";
			vprint "Date: $date";
			$evdate=$date;
		}
		$/=$dave;

		my @PRICES=undef;
		my $i=0;
		for my $sp ($div->find('a.bet\ \ ')->each ) { 
			my $x= $sp->text; 
#			vprint "BET:$x\n";
			$PRICES[$i++]=$x;
		}

		$market="1";
		$price=$PRICES[0];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="X";
		$price=$PRICES[1];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="2";
		$price=$PRICES[2];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="1Χ";
		$price=$PRICES[3];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="12";
		$price=$PRICES[4];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="2Χ";
		$price=$PRICES[5];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		my $under=$PRICES[7];

        my $valid=0;
        foreach my $val (@validOU) {
            if ($under == $val ) {
                $valid=1;
            }
        }

		$market="ΣΥΝΟΛΙΚΟ OVER ($under)";
		$price=$PRICES[6];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="ΣΥΝΟΛΙΚΟ UNDER ($under)";
		$price=$PRICES[8];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="GG";
		$price=$PRICES[15];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="NG";
		$price=$PRICES[16];
		vprint "MARKET $market PRICE $price";
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	
	}
	undef $firefox;
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

	my $response=$firefox->get($url);
	sleep(1);

	vprint "MOJO work\n";

	my $dom=Mojo::DOM->new($firefox->content);
		my $game="";
		my $market="";
		my $price="";
		my $opp1="";
		my $opp2="";
		my $date="";
		my $time="";
		my $evdate="";

	my %dates;
	my %gameurls;

	for my $div ($dom->find('div.line')->each) {
		vprint "-------------------------------";
		for my $span ($div->find('span.n')->each) {
			vprint "GAME:"  . $span->{title};
			($opp1,$opp2)=split(' — ',$span->{title});
		}
		$opp2=~ s/\(.*\)//g;
		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";

		my $dave=$/;
		undef $/;
		for my $date ($div->find('div.date\ min')->each) {
			for (my $i=1; $i<=5;$i++ ) {
				$date=~ s/<.*?>//gm;
			}
			my @lines=split(/\n/,$date);
			$date=$lines[3];
			$date=~ s/^\s*//g;
			$date=~ s/\s*$//g;
			$date=~ s/^\"\>//gm;
			$date=~ s/\./\//gm;
			my $year=localtime->year()+1900;
			$date=~ s/ /\/$year /;
			vprint "-------------------------------";
			vprint "Date: $date";
			$evdate=$date;
		}
		$/=$dave;

		my @PRICES=undef;
		my $i=0;
		for my $sp ($div->find('a.bet\ \ ')->each ) { 
			my $x= $sp->text; 
#			vprint "BET:$x\n";
			$PRICES[$i++]=$x;
		}


		$market="1";
		$price=$PRICES[0];
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="2";
		$price=$PRICES[2];
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		my $under=$PRICES[7];

		next unless   looks_like_number($under) ;

		$market="ΣΥΝΟΛΙΚΟ OVER ($under)";
		$price=$PRICES[6];
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	

		$market="ΣΥΝΟΛΙΚΟ UNDER ($under)";
		$price=$PRICES[8];
		domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");	
	}
	undef $firefox;
}



1;
