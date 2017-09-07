#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;
use Try::Tiny;
use List::Util 'shuffle';


sub goalbet_scrape_soccer_games($$$$);
sub goalbet_scrape_basket_games($$$$);
sub	goalbet_scrape($$$$);


my %MONTHS= (
    'Ιανουρίου'	=> '01',
    'Φεβρουαρίου'=> '02',
    'Μαρτίου'	=> '03',
    'Απριλίου'	=> '04',
    'Μαΐου'		=> '05',
    'Ιουνίου'	=> '06',
    'Ιουλίου'	=> '07',
    'Αυγούστου'	=> '08',
    'Σεπτεμβρίου'=> '09',
    'Οκτωβρίου'	=> '10',
    'Νοεμβρίου'	=> '11',
    'Δεκεμβρίου'=> '12'
);


######################################################################
#
# BasketBall scraping
#
######################################################################
sub  do_goalbet_basket($$$) {
	my ($url,$verbose,$site) = @_;

	my $category = "BASKET";
	for (my $i=0;$i<=16;$i++) {
		try {
			goalbet_scrape($url,$verbose,$site,$category);
		} catch {
			warn "caught error: $_";
		};
	}
}

######################################################################
#
# FootBall scraping
#
######################################################################
sub  do_goalbet_soccer($$$) {
	my ($url,$verbose,$site) = @_;

	my $category = "SOCCER";
	for (my $i=0;$i<=16;$i++) {
		try {
			goalbet_scrape($url,$verbose,$site,$category);
		} catch {
			warn "caught error: $_";
		};
	}
}

######################################################################
#
# Common scraping
#
######################################################################
sub goalbet_scrape($$$$) {
	my ($url,$verbose,$site,$category)=@_;
	my $firefox = newFirefox();
	my $response=$firefox->get($url);

    foreach my $selector (shuffle($firefox->selector('a'))) {
    	my $inner= $selector->{innerHTML};
    	my $href = $selector->{href};
		if ($category =~ /SOCCER/ ) {
			next unless ($inner =~ /sel_date/ && $href =~ /Football/ );
		} else {
			next unless ($inner =~ /sel_date/ && $href =~ /Basket/ );
		}
    	$inner =~ s/^\s*<div.*?>\s*//g;
    	$inner =~ s/<\/div>.*$//g;
		my $gamedate=$inner;
		vprint "GAMEDATE $gamedate";
		my ($dayname,$day,$monthname)=split(/\s/,$gamedate);
    	my $year=sprintf( "%4d",localtime->year() + 1900);
		my $evdate=sprintf( "%02d/%02d/%4d",$day,$MONTHS{$monthname},$year);
    	vprint "EVDATE $evdate";
	
		$firefox->click({dom=>$selector,synchronize=>1});
		vprint "CLICKED";

		my @frames=$firefox->xpath('/html/body/table/tbody/tr/td[1]/table',frames => 1,all=>1);
		my $html=$frames[0]->{outerHTML};

		vprint "SCRAPING $category";
		if ($category =~ /SOCCER/ ) {
			goalbet_scrape_soccer_games($site,$category,$evdate,$html);
		} else {
			goalbet_scrape_basket_games($site,$category,$evdate,$html);
		}
		last;
		# only scrape a single date
 	}

}


######################################################################
#
# Soccer
#
######################################################################
sub goalbet_scrape_soccer_games($$$$) {
	my ($site,$category,$gamedate,$html)=@_;
	my $opp1="";
	my $opp2="";

	vprint "SOCCER GAMES PAGE";

    my $te=HTML::TableExtract->new( );
	$te->parse($html);

     foreach my $ts ($te->tables)   {
        my $coords=join(',', $ts->coords);
        vprint "Table ($coords)";
        next unless ($coords eq "0,0");
		foreach my $lrow ($ts->rows) {
		
			my @row=@$lrow;

			my ($protm,$evtime)=split(/\s/,$row[0]);
			my $evdate=$gamedate . " " . $evtime;

			my $couponid=$row[1];
			# whetever starts with a zero is a local code to goalbet
			if ( $couponid =~ /^0/ ) {
				$couponid='';
			}

			$opp1=$row[2];
			$opp2=$row[3];

			next if ($opp1 eq "" || $opp2 eq "" | $opp1 eq "ΓΗΠΕΔΟΥΧΟΣ");

			my $market="1";
			my $price=$row[4];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="X";
			$price=$row[5];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="2";
   	    	$price=$row[6];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="ΣΥΝΟΛΙΚΟ UNDER (2.5)";
   	    	$price=$row[7];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="ΣΥΝΟΛΙΚΟ OVER (2.5)";
   	    	$price=$row[8];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="1Χ";
   	    	$price=$row[9];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="2Χ";
   	    	$price=$row[10];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="12";
   	    	$price=$row[11];
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
		}
	}

}


######################################################################
#
# basket
#
######################################################################
sub goalbet_scrape_basket_games($$$$) {
	my ($site,$category,$gamedate,$html)=@_;
	my $opp1="";
	my $opp2="";

	vprint "BASKET GAMES PAGE";

    my $te=HTML::TableExtract->new( );
	$te->parse($html);

     foreach my $ts ($te->tables)   {
        my $coords=join(',', $ts->coords);
        vprint "Table ($coords)";
        next unless ($coords eq "0,0");
		foreach my $lrow ($ts->rows) {
		
			my @row=@$lrow;

			my $couponid='';
			my ($protm,$evtime)=split(/\s/,$row[0]);
			my $evdate=$gamedate . " " . $evtime;

			$opp1=$row[2];
			$opp2=$row[3];

			next if ($opp1 eq "" || $opp2 eq "" | $opp1 eq "ΓΗΠΕΔΟΥΧΟΣ");

			my @parts=split(/\s/,trim($row[4]));
			my $points=$parts[1];
			my $price=$parts[$#parts];
			my $market="ΣΥΝΟΛΙΚΟ UNDER ($points)";
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			@parts=split(/\s/,trim($row[5]));
			$points=$parts[1];
			$price=$parts[$#parts];
			$market="ΣΥΝΟΛΙΚΟ OVER ($points)";
			vprint "GAME $opp1 v $opp2 at $evdate, $market - $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

		}
	}
}

1;
