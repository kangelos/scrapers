#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Mojo::DOM;


sub vprint($);
sub dprint($);



sub stoiximan_scrape_per_game($$$$$);

# globals careful when threading
my %WEEKDAYS= (
	0 => 'Kyriaki',
	1 => 'Deftera',
	2 => 'Triti',
	3 => 'Tetarti',
	4 => 'Pempti',
	5 => 'Paraskevi',
	6 => 'Sabbato',
	7 => 'Kyriaki',
);


######################################################################
#
# We get these data from stoiximan.gr
#
######################################################################
sub  do_stoiximan_soccer($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="SOCCER";
	my $today=sprintf( "%02d/%02d/%4d",localtime->mday(), localtime->mon()+1,localtime->year() + 1900);
	my $eventdate=sprintf( "%02d/%02d/%4d",localtime->mday(), localtime->mon()+1,localtime->year() + 1900);

	my $wday=localtime->wday();
	my $end_day=($wday+2)%7;

	# fix this for future dates
	for (my $count=0;$count<3;$count++) {
		my %games;
		my $day=($wday+$count) %7;

		vprint $WEEKDAYS{$day} ." $eventdate\n";
		my %PRICES=undef;
		my $firefox = newFirefox();
		my $url=$baseurl . '/' . $WEEKDAYS{$day};
		dprint $url ."\n";
		
		my $response=$firefox->get($url);
		my $html = $firefox->content();

		 my $te=HTML::TableExtract->new( );
		 $te->parse($html);

		 # Examine all matching tables
		 foreach my $ts ($te->tables) 	{
			my $coords=join(',', $ts->coords);
			vprint "First batch:\"$coords\"\n";
			next unless ($coords == "0,0");
			# skip the first line(s)
			my $rc=-1;
				foreach my $lrow ($ts->rows) {
					foreach my $elem (@$lrow) {
						$elem =~ s/\s\s*/ /g;
						$elem =~ s/^\s\s*//g;
						$elem =~ s/\s\s*$//g;
						vprint "$elem|";
					}
					my ($empty,$price1,$pricex,$price2,$OU,$GNG,$somemetric)=@$lrow;
					vprint "$empty,$price1,$pricex,$price2,$OU,$GNG,$somemetric\n";
					my ($O,$priceo,$U,$priceu)=split(/ /,$OU);
					my ($G,$priceg,$N,$pricen)=split(/ /,$GNG);
					$PRICES{$rc,'1'}=$price1;
					$PRICES{$rc,'2'}=$price2;
					$PRICES{$rc,'X'}=$pricex;
					$PRICES{$rc,'O'}=$priceo;
					$PRICES{$rc,'U'}=$priceu;
					$PRICES{$rc,'G'}=$priceg;
					$PRICES{$rc,'N'}=$pricen;
					$rc++;
				}
		}


		vprint "===================================== SECOND PASS =============================";
		# second pass 
		 my $rc=0;
		 foreach my $ts ($te->tables) 	{
			my $coords=join(',', $ts->coords);
			next unless ($coords =~ /^1,\d/);
			my $opp1;
			my $opp2;
			foreach my $lrow ($ts->rows) {
					my $elem= @$lrow[0];
					$elem =~ s/\s\s*/ /g;
					$elem =~ s/^\s\s*//g;
					$elem =~ s/\s\s*$//g;
					vprint $elem."|";
					($opp1,my $rest)=split(' - ',$elem);

					$rest =~ m/(.*)\s(\d\d*)\s(\d\d*\/\d\d*)\s(\d\d*:\d\d*)/;
					my $opp2=$1;
					my $couponid=$2*1;
					my $date=$3;
					my $time=$4;

					my $evdate=sprintf( "%s/%4d %s",$date, localtime->year() + 1900,$time);

					my $price1		=		$PRICES{$rc,'1'};
					my $price2		=		$PRICES{$rc,'2'};
					my $pricex		=		$PRICES{$rc,'X'};
					my $priceo		=		$PRICES{$rc,'O'};
					my $priceu		=		$PRICES{$rc,'U'};
					my $priceg		=		$PRICES{$rc,'G'};
					my $pricen		=		$PRICES{$rc,'N'};
					vprint "PRICES $opp1 , $opp2 , $couponid , $date , $time , $eventdate , $price1 , $price2 , $pricex , $priceo , $priceu , $priceg , $pricen \n";

					domysql($site,$evdate,$opp1,$opp2,$category,'1',					$price1,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'2',					$price2,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'X',					$pricex,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'ΣΥΝΟΛΙΚΟ OVER (2.5)',	$priceo,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'ΣΥΝΟΛΙΚΟ UNDER (2.5)',	$priceu,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'GG',					$priceg,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'NG',					$pricen,1,$couponid);

					$games{"$opp1 v $opp2"}{'date'}=$evdate;
					$rc++;
				}
		}

		vprint "STOIXIMAN SOCCER COUNT $rc";
		next if ($rc == 0);

		# probably basket and soccer are identical, maybe 1xbetcy also
		vprint "===================================== THIRD PASS =============================";
		# third pass , locate selectors
	    foreach my $selector ( $firefox->selector('a')) {
        	my $inner= $selector->{innerHTML};
				$inner =~ s/\n//g;
				$inner =~ s///g;
				$inner =~ s/^\s*<span>\s*//g;
				$inner =~ s/<\/span>.*$//g;
				$inner =~ s/\s*$//g;
				$inner =~ s/^\s*//g;
        		my $id = $selector->{id};
        		my $href = $selector->{href};
				if ( $href =~ /\d+$/ && $inner =~ / - /) {
					next if ( $inner =~ /span/g );
					vprint "=============== '$href' -> '$inner' ";
					# hopefully this matches whatever was in HREFS
					$inner =~ s/ - / v /g;
					vprint "INNER $inner";
					vprint "HREF $href";
					if ( exists($games{$inner}) ) {
						$games{$inner}{'href'}=$href;
						my $date=$games{$inner}{'date'};
						vprint "HREF UPDATED for $inner DATE $date";
					} else {
						vprint "NOT FOUND $inner";
					}
				}
    	}
		par_do(\&stoiximan_scrape_per_game,$category,$site,\%games);
	}
}

######################################################################
#
# We get these data from stoiximan.gr
#
######################################################################
sub  do_stoiximan_basket($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="BASKET";
	my $today=sprintf( "%02d/%02d/%4d",localtime->mday(), localtime->mon()+1,localtime->year() + 1900);
	my $eventdate=sprintf( "%02d/%02d/%4d",localtime->mday(), localtime->mon()+1,localtime->year() + 1900);

	my $wday=localtime->wday();
	my $end_day=($wday+2)%7;

	# fix this for future dates
	for (my $count=0;$count<3;$count++) {
		my %games;
		my $day=($wday+$count) % 7;

		vprint $WEEKDAYS{$day} ." $eventdate\n";
		my %PRICES=undef;

		my $firefox = newFirefox();
		my $url=$baseurl . '/' . $WEEKDAYS{$day};
		vprint "STOIXIMAN BASKET $url ";
		
		my $response=$firefox->get($url);

		my $resp = $firefox->content();
		my $te=HTML::TableExtract->new( );
		$te->parse($resp);

		 # Examine all matching tables
		 foreach my $ts ($te->tables) 	{
			my $coords=join(',', $ts->coords);
			vprint "First batch:\"$coords\"\n";
			next unless ($coords == "0,0");
			# skip the first line(s)
			my $rc=-1;
				foreach my $lrow ($ts->rows) {
					foreach my $elem (@$lrow) {
						$elem =~ s/\s\s*/ /g;
						$elem =~ s/^\s\s*//g;
						$elem =~ s/\s\s*$//g;
						vprint "$elem|";
					}
					my ($empty,$price1,$price2,$handicap,$OU,$somemetric)=@$lrow;
					vprint "$empty,$price1,$price2,$handicap,$OU,$somemetric\n";
					my ($O,$pointso,$priceo,$U,$pointsu,$priceu)=split(/ /,$OU);
					$PRICES{$rc,'1'} = $price1;
					$PRICES{$rc,'2'} = $price2;
					$PRICES{$rc,'PO'}= $pointso;
					$PRICES{$rc,'O'} = $priceo;
					$PRICES{$rc,'PU'}= $pointsu;
					$PRICES{$rc,'U'} = $priceu;
					$rc++;
				}
		}

		# second pass 
		 my $rc=0;
		 foreach my $ts ($te->tables) 	{
			my $coords=join(',', $ts->coords);
			vprint "$coords\n";
			next unless ($coords =~ /^1,\d/);
			my $opp1;
			my $opp2;
			foreach my $lrow ($ts->rows) {
					my $elem= @$lrow[0];
					$elem =~ s/\s\s*/ /g;
					$elem =~ s/^\s\s*//g;
					$elem =~ s/\s\s*$//g;
					vprint $elem."|";
					($opp1,my $rest)=split(' - ',$elem);

					$rest =~ m/(.*)\s(\d\d*)\s(\d\d*\/\d\d*)\s(\d\d*:\d\d*)/;
					my $opp2=$1;
					my $couponid=$2*1;
					my $date=$3;
					my $time=$4;

					my $evdate=sprintf( "%s/%4d %s",$date, localtime->year() + 1900,$time);

					my $price1		=		$PRICES{$rc,'1'};
					my $price2		=		$PRICES{$rc,'2'};
					my $priceo		=		$PRICES{$rc,'O'};
					my $priceu		=		$PRICES{$rc,'U'};
					my $pointso		=		$PRICES{$rc,'PO'};
					my $pointsu		=		$PRICES{$rc,'PU'};
					vprint "Prices: $opp1 , $opp2,$couponid,$date,$time, $eventdate $price1 , $price2 ,$pointso, $priceo ,$pointsu $priceu \n";

					domysql($site,$evdate,$opp1,$opp2,$category,'1',						$price1,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,'2',						$price2,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,"ΣΥΝΟΛΙΚΟ OVER ($pointso)",	$priceo,1,$couponid);
					domysql($site,$evdate,$opp1,$opp2,$category,"ΣΥΝΟΛΙΚΟ UNDER ($pointsu)",$priceu,1,$couponid);
					$games{"$opp1 v $opp2"}{'date'}=$evdate;
					$rc++;
				}
		}

		vprint "STOIXIMAN BASKET COUNT $rc";
		next if ($rc == 0);
		# thirdpass
		foreach my $selector ( $firefox->selector('a')) {
        	my $inner= $selector->{innerHTML};
				$inner =~ s/\n//g;
				$inner =~ s///g;
				$inner =~ s/^\s*<span>\s*//g;
				$inner =~ s/<\/span>.*$//g;
				$inner =~ s/\s*$//g;
				$inner =~ s/^\s*//g;
        		my $id = $selector->{id};
        		my $href = $selector->{href};
				if ( $href=~/\d+$/ && $inner =~ / - /) {
					next if ( $inner =~ /span/g );
					vprint "=============== '$href' -> '$inner' ";
					# hopefully this matches whatever was in HREFS
					$inner =~ s/ - / v /g;
					vprint "INNER $inner";
					vprint "HREF $href";
					if ( exists($games{$inner}) ) {
						$games{$inner}{'href'}=$href;
						my $date=$games{$inner}{'date'};
						vprint "HREF updated for $inner DATE $date";
					} 
				}
    	}
		par_do(\&stoiximan_scrape_per_game,$category,$site,\%games);
	}
}


######################################################################
sub stoiximan_scrape_per_game($$$$$){
	my ($game,$evdate,$url,$category,$site) = @_;

	vprint "GAME $game";
	vprint "URL $url";
	my $firefox = newFirefox();

    my $response=$firefox->get($url);
	foreach my $selector ( $firefox->selector('a')) {
    	my $inner= $selector->{innerHTML};
    	my $id = $selector->{id};
    	my $href = $selector->{href};
		if ( $inner =~ /Όλα/ ) {
			my $xresponse=$firefox->click({dom=>$selector,synchronize=>0});
            sleep(2);
			last;
		}
    }
    my $html=$firefox->content();
    my $dom=Mojo::DOM->new($html);


    for my $marketdiv ($dom->find('div')->each) {
		my $class=$marketdiv->{class};
		next unless ( $class =~ /s.\sjs-market/g);
		vprint "CLASS $class";
		my $market=undef;
    	for my $title ($marketdiv->find('div')->each) {
			my $class=$title->{class};
			next unless ( $class =~ /t.\sjs-market-title\sr.\smr/g);
			vprint "TITLECLASS $class";
			vprint "CONTENTS $title";
			vprint "INNER " .  $title->{innerHTML};
			for my $label ($title->find('label')->each) {
				$market=$label;
				$market=~ s/<label>//g;
				$market=~ s/<\/label>.*//g;
				$market=~ s/^\s*//g;
				$market=~ s/\s*$//g;
				vprint "LABEL $market";
			}
		}
		my $mkt=undef;
		my $price=undef;
        for my $div ($marketdiv->find('div')->each) {
			my $class=$div->{class};
#			vprint "ANOTHER CLASS $class";
			next unless ( $class =~ /s.\sjs-market-body\sr./g);
			foreach my $superclass ('bi','by','c2','bm') {
				for my $bidiv ($div->find("div.${superclass}")->each) {
					for my $sdiv ($bidiv->find()->each) {
						my $class=$sdiv->{class};
						if ( $class eq "m8 s2" ) {
							$mkt=$sdiv;
							$mkt =~ s/<\/div>//g;
							$mkt =~ s/<div.*>//g;
						}
						if ( $class eq "m7 f s3" ) {
							$price=$sdiv;
							$price =~ s/<\/div>//g;
							$price =~ s/<div.*>//g;
						}

						next if ($mkt eq '');

						my $dbmarket= $market;
						my $dbmkt	= $mkt;
						if ( ( $market =~ /Κόρνερ \(90 λεπτά\) - Over\/Under/gi ) || 
							 ( $market =~ /Κόρνερ Over\/Under /gi) ) {
							$dbmarket="ΣΥΝΟΛΙΚΑ ΚΟΡΝΕΡ";
							my ($submarket,$value)=split(/ /,$mkt);
							$dbmkt = $submarket ." (" . $value . ")";
						}

						if ( ( $market =~ /^Γκολ Over\/Under$/gi ) ||
							 ( $market =~ /^Γκολ Over\/Under \(extra\)$/gi ) ) {
							$dbmarket="ΣΥΝΟΛΙΚΟ";
							my ($submarket,$value)=split(/ /,$mkt);
							$dbmkt = $submarket ." (" . $value . ")";
						}

						vprint "Market: $game : '$dbmarket' '$dbmkt' '$price'";
						my ($opp1,$opp2) = split (' v ' ,$game);
						domysql($site,$evdate,$opp1,$opp2,$category,"$dbmarket $dbmkt",$price,1,'-');
					}
				}
			}
		}
	}
#	undef $firefox;
}


1;
