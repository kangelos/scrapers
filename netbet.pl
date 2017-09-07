#!/usr/bin/perl


######################################################################
######################################################################
######################################################################
######################################################################
######################################################################
#under test;
######################################################################
######################################################################
######################################################################
######################################################################
######################################################################


use strict;
use utf8;
use Mojo::DOM;

our $debug;


sub netbet_soccer_extract($$$$);
sub basket_extract($$$$);
sub netbet_get_dateid($);
sub netbet_get_fromdate($);
#
# We get these data from netbet.gr
#
######################################################################
sub  do_netbet_soccer($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="SOCCER";
	vprint "===========================================\n";
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);
	sleep(3);

my $html=$firefox->content();
gettables($html);
return();

	my $dateid=netbet_get_dateid($firefox);
	my $today=netbet_get_fromdate($firefox);

	my $id="date_${dateid}";
	$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
	sleep(4);

	netbet_soccer_extract($firefox->content(),$category,$today,$site);

	# now get the future values
	for (my $f=1; $f<=2; $f++ ) {
		vprint "===========================================\n";
		my $day_id=$dateid+$f;
		vprint "calculated Date id is:$day_id\n";

		# this bit is the same as above
		my $firefox = newFirefox();
		my $response=$firefox->get($baseurl . $day_id . "-" . $day_id);
		sleep(5);

		# make sure we have somehting to click on
		my $dateid=netbet_get_dateid($firefox);
		my $today=netbet_get_fromdate($firefox);

		my $id="date_${day_id}";
		$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
		sleep(2);

		netbet_soccer_extract($firefox->content(),$category,$today,$site);
		undef $firefox;
	}
	undef $firefox;
}



######################################################################
#
# We get these data from netbet.gr
#
######################################################################
sub  do_netbet_basket($$$) {
my ($baseurl,$verbose,$site) = @_;

	my $category="BASKET";
	vprint "===========================================\n";
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);
	sleep(3);

	my $dateid=netbet_get_dateid($firefox);
	my $today=netbet_get_fromdate($firefox);
	
	my $id="date_${dateid}";
	$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
	sleep(2);

	basket_extract($firefox->content(),$category,$today,$site);

	# now go two days in the future
	for (my $f=1;$f<=2;$f++) {
		vprint "===========================================\n";
		my $day_id=$dateid+$f;
		vprint "calculated Date id is:$day_id\n";

		# this bit is the same as above
		my $firefox = newFirefox();

		my $response=$firefox->get($baseurl . $day_id . "-" . $day_id);
		sleep(5);

		my $dateid=netbet_get_dateid($firefox);
		my $today=netbet_get_fromdate($firefox);

		# click on the proper date
		my $id="date_${day_id}";
		$firefox->click({ xpath => qq{//*[\@id="${id}"]} , synchronize => 0 }); 
		sleep(3);

		basket_extract($firefox->content(),$category,$today,$site);
		undef $firefox;
	}
	undef $firefox;
}
1;


#
# Per day soccer extraction
#
######################################################################
sub netbet_soccer_extract($$$$) {
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
			print "\n";
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



#
# Per day basket extraction
#
######################################################################
sub basket_extract($$$$) {
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
			print "\n";
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
sub netbet_get_dateid($) {
	my ($firefox) = @_;
	my $dateid="";
	do {
			my $response=$firefox->reload();
			sleep(5);
		
			my $resp = $firefox->content();
			$resp =~ /tr id="date_([0-9][0-9]*)" class="openEvents"/;
			$dateid=$1;
	}	while ($dateid eq "" ) ;

	vprint "Date id is:$dateid\n";
	return($dateid);
}




######################################################################
sub netbet_get_fromdate($) {
	my ($firefox) = @_;
		my $today="";
		foreach my  $inp ($firefox->selector('//input')) {
				if ($inp->{id} =~ /fromDate/ ) {
				$today=$inp->{value};
			}
		}
	return($today);
}
