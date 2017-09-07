#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;


######################################################################
#
#   generic stuff
#
######################################################################
sub betonews_parse_results($$$) {
my ($content,$eventdate,$verbose) =@_;
# update with the finals and results
 my $re=HTML::TableExtract->new( );
 $re->parse($content);

 # Examine all matching tables
 foreach my $ts ($re->tables) 	{
	#vprint "Table (". join(',', $ts->coords) .  "):\n" if ( $verbose);
	my $coords=join(',', $ts->coords);
	next unless ($coords eq "5,2");
	# print the entries out
	getrows($ts,$verbose);

	my $first=0;
	foreach my $lrow ($ts->rows) {
		# skip the header line
		if ( $first == 0 ) {
			$first++;
			next;
		}
		my @row=@$lrow;

		my $couponid=$row[2];
		$couponid =~ s/ [ ]*$//g;
		my $result=$row[17];
		my $scorefull=$result;
		my $scorehalf=$row[18];
		
		my($score1,$score2)=split('-',$result);
		my $res="-";
		if ( $score1 ne "" && $score2  ne "" ){
			if ($score1 == $score2) {
				$res="X";
			}elsif ($score1 < $score2) {
				$res="2";
			} elsif ($score1 > $score2) {
				$res="1";
			}
			scoreupdate_by_couponid('opap',$couponid,$eventdate,$res,$scorehalf,$scorefull);
		}
	}
  }
}

######################################################################
#
# We get the old data from betonews
#
######################################################################
sub  dobetonewsold($$$$) {
my ($baseurl,$verbose,$testonly,$pastdays) = @_;

	# use this as an eventdate reference
	my $eventdate=sprintf("%4d-%02d-%02d",localtime->year() + 1900,  localtime->mon()+1,localtime->mday());
	my $firefox = newFirefox();

	my $response=$firefox->get($baseurl);
	sleep(1);

	if ( $testonly ) {
		return;
	}

	# find football
	# http://www.betonews.com/table.asp?tp=3062&dd=11&dm=5&dy=2016&lang=gr
	# day -1 = yesterday

	my $dd= localtime->mday()-1;	
	my $dm= localtime->mon()+1;
	my $dy=localtime->year()+1900;
	my $url = $baseurl . "&dd=${dd}&dm=${dm}&dy=${dy}&lang=gr";
	$eventdate=sprintf("%4d-%02d-%02d", $dy, $dm, $dd );

	$response=$firefox->get($url);
	sleep(1);
	# today's data, I think
	betonews_parse_results($firefox->content,$eventdate,$verbose);


	# Now if you need older data (2 days ago and so on) teak the $pastdays variable
	for (my $past_days=-1; $past_days>-1*${pastdays}; $past_days--) {

		# pick the previous day button
		foreach my $selector ( $firefox->selector('a')) {
			my $inner= $selector->{innerHTML};
			my $id = $selector->{id};

			if ( $inner =~ /bt_calprev/gi) {
				my @elems=split('&',$selector->{href});
				my $dy="";
				my $dm="";
				my $dd="";
				foreach my $el (@elems) {
					my ($part,$val)=split('=',$el);
					if ( $part eq 'dy' ) {
						$dy=$val;
					}
					if ( $part eq 'dd' ) {
						$dd=$val;
					}
					if ( $part eq 'dm' ) {
						$dm=$val;
					}
					$eventdate=sprintf("%4d-%02d-%02d",$dy,$dm,$dd );
				}
				my $xresponse=$firefox->click($selector);
				sleep(3);
				last;
			}
		}

		# update with the finals and results
		betonews_parse_results($firefox->content,$eventdate,$verbose);
	}# old data
	undef $firefox;
}

######################################################################
#
# We get the scores from betonews
#
######################################################################
sub  do_betonews_soccer_scores($$) {
my ($baseurl,$verbose) = @_;

	# use this are reference
	my $eventdate=sprintf("%4d-%02d-%02d",localtime->year() + 1900,  localtime->mon()+1,localtime->mday());
	my $category="SOCCER";

	my $firefox = newFirefox();

	vprint $baseurl ."\n";
	my $mday=localtime->mday();
	my $dm= localtime->mon()+1;
	my $dy=localtime->year()+1900;
	my $url = $baseurl . "&dd=${mday}&dm=${dm}&dy=${dy}&lang=gr";
	vprint $url."\n";
	my $response= $firefox->get($url);
	sleep(2);
	# naaah just older stuff
	betonews_parse_results($firefox->content,$eventdate,$verbose);
	undef $firefox;
}

######################################################################
#
# We get the future data from betonews
#
######################################################################
sub  do_betonews_soccer($$) {
my ($baseurl,$verbose) = @_;

	# use this are reference
	my $eventdate=sprintf("%4d-%02d-%02d",localtime->year() + 1900,  localtime->mon()+1,localtime->mday());
	my $category="SOCCER";

	my $firefox=newFirefox();

	# get today's data plus 2 days in advance
	#
	vprint $baseurl ."\n";
	for (my $mday=localtime->mday(); $mday < localtime->mday()+3; $mday++ ) {
			my $dm= localtime->mon()+1;
			my $dy=localtime->year()+1900;
			my $url = $baseurl . "&dd=${mday}&dm=${dm}&dy=${dy}&lang=gr";
			vprint $url."\n";

			my $today	= sprintf( "%02d/%02d/%4d", $mday, $dm, $dy );
			$eventdate	= sprintf("%4d-%02d-%02d", $dy,   $dm, $mday );
			my $response= $firefox->get($url);
			sleep(1);
			# naaah just older stuff
			betonews_parse_results($firefox->content,$eventdate,$verbose);

			 my $te=HTML::TableExtract->new( );
			 $te->parse($firefox->content);

			 # Examine all matching tables
			 foreach my $ts ($te->tables) 	{
				#vprint "Table (". join(',', $ts->coords) . "):\n";
				my $coords=join(',', $ts->coords);
				next unless ($coords eq "5,2");
				getrows($ts,$verbose);

				my $first=0;
				foreach my $lrow ($ts->rows) {
				# skip the header line
					if ( $first == 0 ) {
						$first++;
						next;
					}
					my @row=@$lrow;

					my $opp1=$row[6];
					my $opp2=$row[10];
					my $evdate = $today . " " .  $row[1];
					my $couponid=$row[2];

					$opp1 =~ s/\'//g;
					$opp1 =~ s/\s\s*$//g;
					$opp1 =~ s/^\s\s*//g;
					$opp1 =~ s/\s\s*/ /g;

					$opp2 =~ s/\'//g;
					$opp2 =~ s/\s\s*$//g;
					$opp2 =~ s/^\s\s*//g;
					$opp2 =~ s/\s\s*/ /g;

					$evdate =~ s/ [ ]*$//g;
					$evdate =~ s/\s\s*$//g;

					my $game=$opp1 . " v " . $opp2;
					next if ( $game eq " v ");
					vprint ">>>$game\n";

					my $market="1";
					my $price=$row[4];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


					$market="X";
					$price=$row[8];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


					$market="2";
					$price=$row[12];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


					$market="ΣΥΝΟΛΙΚΟ UNDER (2.5)";
					$price=$row[13];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


					$market="ΣΥΝΟΛΙΚΟ OVER (2.5)";
					$price=$row[14];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
				}
			}	
	}
	undef $firefox;
}

######################################################################
#
# We get the future data from betonews,
# but the basket data are no good ,
# so we wait for this to be fixed
#
######################################################################
sub  do_betonews_basket($$) {
my ($baseurl,$verbose) = @_;

	# use this as reference
	my $eventdate=sprintf("%4d-%02d-%02d",localtime->year() + 1900,  localtime->mon()+1,localtime->mday());
	my $category="BASKET";

	my $firefox=newFirefox();

	# get today's data plus 2 days in advance
	#
	vprint $baseurl ."\n";
	for (my $mday=localtime->mday(); $mday < localtime->mday()+3; $mday++ ) {
			my $dm	= localtime->mon()+1;
			my $dy	= localtime->year()+1900;
			$eventdate=sprintf("%4d-%02d-%02d",$dy,$dm,$mday );
			my $today=sprintf( "%02d/%02d/%4d",$mday, $dm,$dy);

			my $url = $baseurl . "&dd=${mday}&dm=${dm}&dy=${dy}&lang=gr";
			vprint $url."\n";

			my $response=$firefox->get($url);
			sleep(1);

			# naaah just older stuff
			betonews_parse_results($firefox->content,$eventdate,$verbose);

			 my $te=HTML::TableExtract->new( );
			 $te->parse($firefox->content);

			 # Examine all matching tables
			 foreach my $ts ($te->tables) 	{
				#vprint "Table (". join(',', $ts->coords) . "):\n";
				my $coords=join(',', $ts->coords);
				next unless ($coords eq "5,2");
				getrows($ts,$verbose);

				my $first=0;
				foreach my $lrow ($ts->rows) {
				# skip the header line
					if ( $first == 0 ) {
						$first++;
						next;
					}
					my @row=@$lrow;

					my $opp1=$row[8];
					my $opp2=$row[11];
					my $evdate = $today . " " .  $row[1];
					my $couponid=$row[2];

					$opp1 =~ s/\'//g;
					$opp1 =~ s/\s\s*$//g;
					$opp1 =~ s/^\s\s*//g;
					$opp1 =~ s/\s\s*/ /g;

					$opp2 =~ s/\'//g;
					$opp2 =~ s/\s\s*$//g;
					$opp2 =~ s/^\s\s*//g;
					$opp2 =~ s/\s\s*/ /g;

					$evdate =~ s/ [ ]*$//g;
					$evdate =~ s/\s\s*$//g;

					my $game=$opp1 . " v " . $opp2;
					next if ( $game eq " v ");
					vprint ">>>$game\n";

					my $market="1";
					my $price=$row[6];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


#					$market="X";
#					$price=$row[8];
#					$price =~ s/,/./g;
#					$price =~ s/ $//g;
#					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


					$market="2";
					$price=$row[13];
					$price =~ s/,/./g;
					$price =~ s/ $//g;
					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);


#					$market="ΣΥΝΟΛΙΚΟ UNDER (2.5)";
#					$price=$row[13];
#					$price =~ s/,/./g;
#					$price =~ s/ $//g;
#					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
#
#
#					$market="ΣΥΝΟΛΙΚΟ OVER (2.5)";
#					$price=$row[14];
#					$price =~ s/,/./g;
#					$price =~ s/ $//g;
#					domysql('opap',$evdate,$opp1,$opp2,$category,$market,$price,1,$couponid);
				}
			}	
	}
	undef $firefox;
}
1;
