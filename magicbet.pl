#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;

sub vprint($);
sub magicbet_soccer_extract($$$$);

######################################################################
#
# We get these data from magicbet.gr
#
######################################################################
sub  do_magicbet_soccer($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="SOCCER";
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);
	# do 4 days in the future
	my $cnt=0;
	foreach my $selector ( $firefox->selector('a')) {
		last if ($cnt>4);
 		my $inner= $selector->{innerHTML};
		next unless ($inner =~ /\s\d\d\/\d\d/);
		vprint "INNER $inner\n";
		$cnt++;
		my ($dayname,$date)=split(/ /,$inner);
		my $today=sprintf( "%s/%4d",$date,localtime->year() + 1900);
		vprint "TODAY $today";
		my $xresponse=$firefox->click({dom=>$selector,synchronize=>0});
		sleep(2);
		magicbet_soccer_extract($firefox->content(),$category,$today,$site);
	}
	vprint "Done";
}



######################################################################
#
# Per day soccer extraction
#
######################################################################
sub magicbet_soccer_extract($$$$) {
my ($html,$category,$today,$site)=@_;
	my $te=HTML::TableExtract->new( );
	$te->parse($html);

	my $couponid="";
	 # Examine all matching tables
	 foreach my $ts ($te->tables) 	{
	 	vprint "Table (". join(',', $ts->coords) . "):\n\n\n";
		my $coords=join(',', $ts->coords);
#		next unless ($coords eq "0,0");

		foreach my $lrow ($ts->rows) {
			vprint join('|', @$lrow);
			my @row=@$lrow;

#|13:30|Αυστραλία - Ιράκ|1,35|4,60|8,50|1,05|1,15|2,65|1,90|1,75|2,15|1,60|+246|

			my $evtime=$row[1];

			my $evdate=$today. " " . $evtime;
			
			my ($opp1,$opp2)=split(/-/,$row[2]);

			$opp1=trim($opp1);
			$opp2=trim($opp2);

			vprint "GAME $opp1 v $opp2 , $evtime";

			my $market="1";
			my $price=$row[3];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="X";
			$price=$row[4];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="2";
			$price=$row[5];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			# greek chi
			$market="1Χ";
			$price=$row[6];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="12";
			$price=$row[7];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			# greek chi
			$market="2Χ";
			$price=$row[8];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="ΣΥΝΟΛΙΚΟ UNDER (2.5)";
			$price=$row[9];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="ΣΥΝΟΛΙΚΟ OVER (2.5)";
			$price=$row[10];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="GG";
			$price=$row[11];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="NG";
			$price=$row[12];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


		} # for each row
	} # for each table
}


1;
