#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;
use Switch;

sub vprint($);
sub betshop_soccer_extract($$$);
sub betshop_basket_extract($$$);
sub betshop_common($);

######################################################################
#
# We get these data from betshop.gr
#
######################################################################
sub  do_betshop_soccer($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="SOCCER";
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);
	betshop_soccer_extract($firefox->content(),$category,$site);
	vprint "Done";
}

######################################################################
#
# basketball
#
######################################################################
sub  do_betshop_basket($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="BASKET";
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);
	betshop_basket_extract($firefox->content(),$category,$site);
	vprint "Done";
}



######################################################################
#
# Per day soccer extraction
#
######################################################################
sub betshop_soccer_extract($$$) {
my ($html,$category,$site)=@_;

	my $today="";
	my $game="";
	my $market="";
	my $price="";
	my $opp1="";
	my $opp2="";
	my $date="";
	my $time="";
	my $evdate="";
	my $evtime="";

	vprint "MOJO work\n";
	my $dom=Mojo::DOM->new($html);
	for my $table ($dom->find('table.sports-table\ collapse-container')->each) {
		for my $tr ($table->find('tr')->each) {
			my $tdc=0;
			for my $td ($tr->find('td')->each) {
				if ( $tdc==0) {
					$opp1="";
					$opp2="";
					for my $span ($td->find('span.name')->each) {
						my $participant=$span->text;
						vprint "PARTICIPANT:$participant";
						if ( $opp1 eq "" ) {
							$opp1=$participant;
						} elsif ( $opp2 eq "" ) {
							$opp2=$participant;
						}
					}
					vprint "OPP1 $opp1 OPP2 $opp2";
					for my $c  ($td->find('div.datetime')->each) {
						$date=$c->text;
						for  my $s  ($c->find('span.time')->each) {
							$evtime=$s->text;
						}
					}
					my ($day,$today)=split(/,/,$date);
					$today=trim($today);
					$evdate=sprintf( "%s/%4d %s",$today ,localtime->year() + 1900,$evtime);
				}
				if ( $tdc == 1 ) {
					my $spanc=0;
					for my $span  ($td->find('span.ov')->each) {
						vprint "SPAN $spanc " . $span->text;
						switch ($spanc ) {
							case (0) {
								$market="1";
								$price=$span->text;
							}
							case (1) {
								$market="X";
								$price=$span->text;
							}
							case (2) {
								$market="2";
								$price=$span->text;
							}
						}
						$price=~s/,/\./g;
						vprint "MARKET $market PRICE $price";
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$spanc++;
					}
				}
				if ( $tdc == 2 ) {
					my $spanc=0;
					for my $span  ($td->find('span.ov')->each) {
						vprint "SPAN $spanc " . $span->text;
						switch ($spanc ) {
							case (0) {
								$market="ΣΥΝΟΛΙΚΟ UNDER (2.5)";
								$price=$span->text;
							}
							case (1) {
								$market="ΣΥΝΟΛΙΚΟ OVER (2.5)";
								$price=$span->text;
							}
						}
						$price=~s/,/\./g;
						vprint "MARKET $market PRICE $price";
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$spanc++;
					}
				}
				if ( $tdc == 3 ) {
					my $spanc=0;
					for my $span  ($td->find('span.ov')->each) {
						vprint "SPAN $spanc " . $span->text;
						switch ($spanc ) {
							case (0) {
								$market="GG";
								$price=$span->text;
							}
							case (1) {
								$market="NG";
								$price=$span->text;
							}
						}
						$price=~s/,/\./g;
						vprint "MARKET $market PRICE $price";
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$spanc++;
					}
				}

				$tdc++;
			} #td
		} #tr
	} #table
}

######################################################################
#
# Per day basketball extraction
#
######################################################################
sub betshop_basket_extract($$$) {
my ($html,$category,$site)=@_;

	my $today="";
	my $game="";
	my $market="";
	my $price="";
	my $opp1="";
	my $opp2="";
	my $date="";
	my $time="";
	my $evdate="";
	my $evtime="";
	my $ou="";
	my $priceo="";
	my $priceu="";

	vprint "MOJO work\n";
	my $dom=Mojo::DOM->new($html);
	for my $table ($dom->find('table.sports-table\ collapse-container')->each) {
		$ou="";
		$priceo="";
		$priceu="";
		for my $tr ($table->find('tr')->each) {
			my $tdc=0;
			for my $td ($tr->find('td')->each) {
				if ( $tdc==0) {
					($opp1,$opp2,$evdate)=betshop_common($td);
				}
				if ( $tdc == 1 ) {
					my $spanc=0;
					for my $span  ($td->find('span.ov')->each) {
						vprint "SPAN $spanc " . $span->text;
						switch ($spanc ) {
							case (0) {
								$market="1";
								$price=$span->text;
							}
							case (1) {
								$market="2";
								$price=$span->text;
							}
						}
						$price=~s/,/\./g;
						vprint "MARKET $market PRICE $price";
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$spanc++;
					}
				}
				if ( $tdc == 2 ) {
					for my $span  ($td->find('span.middle')->each) {
						$ou=$span->text;
						vprint "OU $ou";
					}
					my $spanc=0;
					for my $span  ($td->find('span.ov')->each) {
						vprint "SPAN $spanc " . $span->text;
						switch ($spanc ) {
							case (0) {
								$market="ΣΥΝΟΛΙΚΟ UNDER ($ou)";
								$priceu=$span->text;
								$priceu=~s/,/\./g;
								vprint "MARKET ΣΥΝΟΛΙΚΟ UNDER ($ou) PRICE $priceu";
								domysql($site,$evdate,$opp1,$opp2,$category,$market,$priceu,1,'');
							}
							case (1) {
								$market="ΣΥΝΟΛΙΚΟ OVER ($ou)";
								$priceo=$span->text;
								$priceo=~s/,/\./g;
								vprint "MARKET ΣΥΝΟΛΙΚΟ OVER ($ou) PRICE $priceo";
								domysql($site,$evdate,$opp1,$opp2,$category,$market,$priceo,1,'');
							}
						}
					}
					$spanc++;
				}
				$tdc++;
			} #td
		} #tr
	} #table
}

######################################################################
sub betshop_common($) {
	my ($td)=@_;

	my $opp1="";
	my $opp2="";
	my $date="";
	my $evtime="";
	my $evdate="";

	for my $span ($td->find('span.name')->each) {
		my $participant=$span->text;
		vprint "PARTICIPANT:$participant";
		if ( $opp1 eq "" ) {
			$opp1=$participant;
		} elsif ( $opp2 eq "" ) {
			$opp2=$participant;
		}
	}
	vprint "OPP1 $opp1 OPP2 $opp2";
	for my $c  ($td->find('div.datetime')->each) {
		$date=$c->text;
		for  my $s  ($c->find('span.time')->each) {
			$evtime=$s->text;
		}
	}
	my ($day,$today)=split(/,/,$date);
	$today=trim($today);
	$evdate=sprintf( "%s/%4d %s",$today ,localtime->year() + 1900,$evtime);

	return ($opp1,$opp2,$evdate);
}

1;





