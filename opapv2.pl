#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;

sub vprint($);
sub opap_soccer_extract($$$$);
sub opap_basket_extract($$$$);
sub opap_get_dateid($);
sub opap_get_fromdate($);
sub opap_scrape_per_game($$$$$) ;
sub opap_per_game_extract($$$$) ;

######################################################################
#
# We get these data from opap.gr
#
######################################################################
sub  do_opap_soccer($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="SOCCER";
	vprint "===========================================\n";
		my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);

	my $dateid=opap_get_dateid($firefox);
	if ( $dateid eq "" ) {
		vprint "Invalid Coupon";
		return;
	}
   my $today=opap_get_fromdate($firefox);

	my $id="date_${dateid}";
	$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
	sleep(4);
###########
   opap_soccer_extract($firefox->content(),$category,$today,$site);
   opap_per_game_extract($firefox,$today,$category,$site);
###########
	# now get the future values
	for (my $f=1; $f<=2; $f++ ) {
		vprint "===========================================\n";
		my $day_id=$dateid+$f;
		vprint "calculated Date id is:$day_id\n";

		# this bit is the same as above
		my $firefox = newFirefox();

		my $response=$firefox->get($baseurl . $day_id . "-" . $day_id);

		# make sure we have somehting to click on
		my $dateid=opap_get_dateid($firefox);
		if ( $dateid eq "" ) {
			vprint "Invalid Coupon";
			return;
		}
		my $today=opap_get_fromdate($firefox);

		my $id="date_${day_id}";
		$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
		sleep(3);

		opap_soccer_extract($firefox->content(),$category,$today,$site);
		opap_per_game_extract($firefox,$today,$category,$site);
	}
}



######################################################################
#
# We get these data from opap.gr
#
######################################################################
sub  do_opap_basket($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="BASKET";
	vprint "===========================================\n";
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);

	my $dateid=opap_get_dateid($firefox);
	if ( $dateid eq "" ) {
		vprint "Invalid Coupon";
		return;
	}
   my $today=opap_get_fromdate($firefox);
   
	my $id="date_${dateid}";
	$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
	sleep(2);

   opap_basket_extract($firefox->content(),$category,$today,$site);
   opap_per_game_extract($firefox,$today,$category,$site);

	# now go two days in the future
	for (my $f=1;$f<=2;$f++) {
		vprint "===========================================\n";
		my $day_id=$dateid+$f;
		vprint "calculated Date id is:$day_id\n";

		# this bit is the same as above
		my $firefox = newFirefox();

		my $response=$firefox->get($baseurl . $day_id . "-" . $day_id);

		my $dateid=opap_get_dateid($firefox);
		if ( $dateid eq "" ) {
			vprint "Invalid Coupon";
			return;
		}
		my $today=opap_get_fromdate($firefox);

		# click on the proper date
		my $id="date_${day_id}";
		$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
		sleep(3);

		opap_basket_extract($firefox->content(),$category,$today,$site);
		opap_per_game_extract($firefox,$today,$category,$site);
	}
	undef $firefox;
}


######################################################################
#
# Per day soccer extraction
#
######################################################################
sub opap_soccer_extract($$$$) {
my ($html,$category,$today,$site)=@_;
	my($mday,$mon,$year)=split('/',$today);
	my $eventdate	= sprintf("%4d-%02d-%02d",$year,$mon,$mday);

	my $te=HTML::TableExtract->new( );
	$te->parse($html);

	 # Examine all matching tables
	 foreach my $ts ($te->tables) 	{
	 	vprint "Table (". join(',', $ts->coords) . "):\n\n\n";
		my $coords=join(',', $ts->coords);
		next unless ($coords eq "0,0");
		foreach my $lrow ($ts->rows) {
			vprint join('|', @$lrow);
		}

		my $first=0;
		foreach my $lrow ($ts->rows) {
		# skip the first line(s)
			if ( $first < 1 ) {
				$first++;
				next;
			}
			my @row=@$lrow;

			my $opp1=$row[6];
			$opp1=~ s/ .$//g;

			next if ($opp1 =~ /ΓΗΠΕΔΟΥΧΟΣ/gi );

			my $opp2=$row[8];
			my $evdate = $today . " " .  $row[1];
			my $couponid=$row[3];

			$opp1 =~ s/\'//g;
			$opp2 =~ s/\'//g;

			$opp1 =~ s/ [ ]*$//g;
			$opp2 =~ s/ [ ]*$//g;

			$opp2 =~ s/ [ ]*/ /g;
            $opp1 =~ s/ [ ]*/ /g;


            $opp1 =~ s/^ [ ]*//g;
			$opp2 =~ s/^ [ ]*//g;

			$couponid =~ s/ [ ]*$//g;

			$evdate =~ s/ [ ]*$//g;

			my $game=$opp1 . " v " . $opp2;
			next if ( $game eq " v ");
			vprint ">>>$game\n";

			my $market="1";
			my $price=$row[5];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="X";
			$price=$row[7];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="2";
			$price=$row[9];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			# greek chi
			$market="1Χ";
			$price=$row[10];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="12";
			$price=$row[11];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			# greek chi
			$market="2Χ";
			$price=$row[12];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="GG";
			$price=$row[16];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="NG";
			$price=$row[17];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="ΣΥΝΟΛΙΚΟ UNDER (2.5)";
			$price=$row[22];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="ΣΥΝΟΛΙΚΟ OVER (2.5)";
			$price=$row[23];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			$market="ΣΥΝΟΛΙΚΟ UNDER (3.5)";
			$price=$row[24];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="ΣΥΝΟΛΙΚΟ OVER (3.5)";
			$price=$row[25];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			my $scorehalf	= $row[36];
			my $result		= $row[37];
			my $scorefull	= $result;

			vprint "Result is $result halftime: $scorehalf fulltime: $scorefull\n";

	        my $res="-";
			my ($score1,$score2)=split(':',$result);
        	 if ( ( $score1 ne "" ) && ( $score2 ne "" )){
                 if ($score1==$score2) {
                         $res="X";
                 }elsif ($score1<$score2) {
                         $res="2";
                 } elsif ($score1>$score2) {
                         $res="1";
           		}
         		scoreupdate_by_couponid($site,$couponid,$eventdate,$res,$scorehalf,$scorefull);
         	}
		} # for each row
	} # for each table
}



######################################################################
#
# Per day basket extraction
#
######################################################################
sub opap_basket_extract($$$$) {
my ($html,$category,$today,$site)=@_;
	my($mday,$mon,$year)=split('/',$today);
	my $eventdate	= sprintf("%4d-%02d-%02d",$year,$mon,$mday);

	 my $te=HTML::TableExtract->new( );
	 $te->parse($html);

	 # Examine all matching tables
	 foreach my $ts ($te->tables) 	{
	 	vprint "Table (". join(',', $ts->coords). "):\n\n\n";
		my $coords=join(',', $ts->coords);
		next unless ($coords eq "0,0");
		foreach my $lrow ($ts->rows) {
			vprint join('|', @$lrow) ;
		}
		

		my $first=0;
		foreach my $lrow ($ts->rows) {
		# skip the first line(s)
			if ( $first < 1 ) {
				$first++;
				next;
			}
			my @row=@$lrow;

			my $opp1=$row[7];
			$opp1=~ s/ .$//g;

			next if ($opp1 =~ /ΓΗΠΕΔΟΥΧΟΣ/gi );

			my $opp2=$row[8];
			my $evdate = $today . " " .  $row[1];
			my $couponid=$row[3];

			$opp1 =~ s/\'//g;
			$opp1 =~ s/ [ ]*$//g;
            $opp1 =~ s/^ [ ]*//g;
            $opp1 =~ s/ [ ]*/ /g;

			$opp2 =~ s/\'//g;
			$opp2 =~ s/ [ ]*$//g;
			$opp2 =~ s/^ [ ]*//g;
			$opp2 =~ s/ [ ]*/ /g;

			my $limit=$row[14];
			$limit =~ s/\'//g;
			$limit =~ s/ [ ]*$//g;
			$limit =~ s/^ [ ]*//g;
			$limit =~ s/ [ ]*/ /g;


			$couponid =~ s/ [ ]*$//g;

			$evdate =~ s/ [ ]*$//g;

			my $game=$opp1 . " v " . $opp2;
			next if ( $game eq " v ");
			vprint ">>>$game\n";

			my $market="1";
			my $price=$row[11];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);



			$market="2";
			$price=$row[12];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="ΣΥΝΟΛΙΚΟ UNDER ($limit)";
			$price=$row[13];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


			$market="ΣΥΝΟΛΙΚΟ OVER ($limit)";
			$price=$row[15];
			$price =~ s/,/./g;
			$price =~ s/ $//g;
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);

			my $scorehalf	= $row[35];
			my $result		= $row[36];
			my $scorefull	= $result;

			vprint "Result is $result halftime: $scorehalf fulltime: $scorefull\n";

	        my $res="-";
			my ($score1,$score2)=split(':',$result);
			if ( ( $score1 ne "" ) && ( $score2 ne "" )){
			        if ($score1==$score2) {
			                $res="X";
			        }elsif ($score1<$score2) {
			                $res="2";
			        } elsif ($score1>$score2) {
			                $res="1";
			 		}
				scoreupdate_by_couponid($site,$couponid,$eventdate,$res,$scorehalf,$scorefull);
			}
		} # for each row
	}	# for each table
}

######################################################################
sub opap_get_dateid($) {
	my ($firefox) = @_;
### <tr id="date_370" style="cursor:pointer" class="closeEvents">
	my $resp = $firefox->content();
	$resp =~ /<tr id="date_([0-9][0-9]*)" /;
	my $dateid=$1;
	my $cnt=0;
	while ($dateid eq "" && $cnt < 5 ) {
		vprint "No date found,reloading";
		my $response=$firefox->reload();
		sleep(5);
	
		my $resp = $firefox->content();
		$resp =~ /<tr id="date_([0-9][0-9]*)" /;
		$dateid=$1;
		$cnt++;
	}

	vprint "Date id is:$dateid\n";
	return($dateid);
}




######################################################################
sub opap_get_fromdate($) {
	my ($firefox) = @_;
		my $today="";
		foreach my  $inp ($firefox->selector('//input')) {
				if ($inp->{id} =~ /fromDate/ ) {
				$today=$inp->{value};
			}
		}
	return($today);
}


######################################################################
sub opap_scrape_per_game($$$$$){
	my ($dummygame,$evdate,$url,$category,$site) =@_;

	my $firefox = newFirefox();

    my $response=$firefox->get($url);
    foreach my $selector ( $firefox->selector('a')) {
    	my $inner= $selector->{innerHTML};
		if ( $inner =~ /Άνοιγμα Όλων/g )  {
			my $xresponse=$firefox->click({dom=>$selector,synchronize=>0});
      	}
    }

	my $html=$firefox->content();
	my $dom=Mojo::DOM->new($html);

	my $couponid="";
    	for my $h3 ($dom->find('h3.head-game-data')->each) {
			$couponid=$h3;
			$couponid =~ m/ΚΩΔ\.\s+(\d+)/;
			$couponid = $1;
		}

	my $opp1="";
	my $opp2="";
	for my $span ($dom->find('span.match')->each) {
			$span =~ s/<.*?>//g;
			$span =~ s/<.*?>//g;
			($opp1,$opp2) = split(' - ',$span);
		}


	vprint "MATCH: $opp1 v $opp2 coupon:$couponid";

    my $score="";
	my $market="";
	my $mkt="";
	my $price="";
    	for my $div ($dom->find('div')->each) {
			next unless ($div->{class} =~ /^slv-market-box-holder\s/ ) ;
			# divs are in pairs and not nested
    		if ( $div->{class} =~ /slv-market-box-holder\ slv-market-details\ correctMarket\ clearfix\ / ) {
					$market=$div;
					$market =~ s/<span.*$//g;
					$market =~ s/\s+$//g;
					$market =~ s/^\s+//g;
					$market =~ /<p>(.*)<\/p>/g;
					$market = $1;
			}	
		
    		for my $a ($div->find('a')->each) {
				$mkt=$a;
				$mkt  =~ s/<span.*$//g;
				$mkt=~ s/<.*?>//g;
				$mkt=~ s/\s+$//g;
				$mkt=~ s/^\s+//g;
    			for my $span ($a->find('span')->each) {
					$span=~ s/<.*?>//g;
					$span=~ s/^\s+//g;
					$span=~ s/\s+$//g;
					$span=~ s/,/./g;
					$price=$span;
					# vprint "PRICE:". $span;
				}
			next if ($market eq $mkt);

			my $dbmkt=$market . " " . $mkt;

			my $goals="";
			if ( $market =~ /ΣΥΝΟΛΙΚΟΣ ΑΡΙΘΜΟΣ ΚΟΡΝΕΡ/ ) {
				$mkt =~ s/^.* - //g;
				$dbmkt=$market . " " . $mkt;
			}

			if ( $market =~ /^UNDER\/OVER\s.*\d$/ ||  $market =~ /^UNDER\/OVER ΠΟΝΤΩΝ ΑΓΩΝΑ\s.*\d$/ ) {
				$market =~ m/(\d+.*)/;
				$goals=$1;
				$goals=~ s/,/./g;	
				if ( $mkt =~ /^O/ ) {
					$dbmkt="ΣΥΝΟΛΙΚΟ OVER (${goals})";
				} else {
					$dbmkt="ΣΥΝΟΛΙΚΟ UNDER (${goals})";
				}
			}

			if ( $market =~ /^ΚΟΡΝΕΡ ΤΡΙΠΛΗΣ ΕΠΙΛΟΓHΣ/ ) {
				if(	$mkt =~ m/.*U\s(\d+,\d+)$/ ) {
					$goals=$1;
					$goals=~ s/,/./g;	
					$dbmkt="ΣΥΝΟΛΙΚΑ ΚΟΡΝΕΡ UNDER (${goals})";
				}
				if(	$mkt =~ m/.*O\s(\d+,\d+)$/ ){
					$goals=$1;
					$goals=~ s/,/./g;	
					$dbmkt="ΣΥΝΟΛΙΚΑ ΚΟΡΝΕΡ OVER (${goals})";
				}
			}
			#vprint "Original Market:$market mkt:$mkt Converted:$dbmkt Price:$price";
			vprint "${opp1} v ${opp2} Market:$dbmkt Price:$price";
			domysql($site,$evdate,$opp1,$opp2,$category,$dbmkt,$price,1,$couponid);
		}
	}
}




######################################################################
sub opap_per_game_extract($$$$){

	my ($firefox,$evdate,$category,$site) =@_;

    #find the link to the football coupon page
	my %games;
    foreach my $selector ( $firefox->selector('a')) {
        my $inner= $selector->{innerHTML};
        my $href= $selector->{href};
        my $id = $selector->{id};

		if ( $id =~ /retailRowLink_(\d+)/ ) {
			vprint "FOUND GAME LINK ID $id NUM $1 INNER $inner \n";
			my $url = "http://praktoreio.pamestoixima.gr/el/retail-event#e/$1";
			$games{$url}=$evdate;
		}
		
     }
	undef $firefox;
	par_do(\&opap_scrape_per_game,$category,$site,\%games);
}

1;
