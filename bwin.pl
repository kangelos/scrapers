#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;
use List::Util 'shuffle';
use HTML::TableExtract;


sub vprint($);
sub bwin_soccer_extract($$$);
sub bwin_grab($);
sub bwin_grabou($);
sub bwin_graboucorner($);

######################################################################
#
# We get these data from bwin.gr
#
######################################################################
sub  do_bwin_soccer($$$) {
my ($baseurl,$verbose,$site) = @_;
	my @games;

	my $category="SOCCER";
    my $firefox = newFirefox();
    my $response=$firefox->get($baseurl);

    vprint "MOJO work\n";
    my $dom=Mojo::DOM->new($firefox->content);

	#find the urls
    for my $boarddiv ($dom->find('div.marketboard-event-without-header')->each) {
        for my $a ($boarddiv->find('a.mb-event-details-buttons__button-link')->each) {
			my $ref=$a->{href};
			next if ( $ref =~ /stat/ );
			$ref= 'https://sports.bwin.gr' . $ref;
			push @games,$ref;
		}
	}

#	# another par_do is needed here
#	foreach my $url (shuffle (@games)) { 
#		bwin_soccer_extract($url,$category,$site);
#	}	
	simpar_do_threaded(\&bwin_soccer_extract,$category,$site,\@games);
	vprint "Done";
}



######################################################################
#
# Per game soccer extraction
#
######################################################################
sub bwin_soccer_extract($$$) {
my ($url,$category,$site)=@_;

    my $game="";
    my $market="";
    my $price="";
    my $opp1="";
    my $opp2="";
    my $date="";
    my $time="";
    my $evdate="";

    my $firefox = newFirefox();
    my $response=$firefox->get($url);

    vprint "URL: " . $url;
    vprint "$category MOJO work\n";

    my $dom=Mojo::DOM->new($firefox->content);

    for my $div ($dom->find('div.event-wrapper')->each) {
        for my $h1 ($div->find('h1.event-block__event-name')->each) {
			$game=$h1->text;			
		}
        for my $span ($div->find('span.event-block__start-date')->each) {
			my $eventdate=$span->text;
			$evdate=$eventdate;
			$evdate=~s/,//g;
			$evdate =~ m/(\d{1,})\/(\d{1,})\/(\d{1,}) (\d{1,}):(\d{1,})/;
			my $day=$1;
			my $mon=$2;
			my $year=$3;
			my $hour=$4;
			my $min=$5;
			if ($evdate =~ /μμ/ ) {
				$hour += 12;
			}
			$evdate=sprintf("%02d/%02d/%04d %02d:%02d",$day,$mon,$year,$hour,$min);
		}
	
		vprint "GAME : $game";
		($opp1,$opp2)=split(/-/,$game);
		$opp1=trim($opp1);
		$opp2=trim($opp2);
		vprint "DATE : $evdate";
		vprint "OPP1 : $opp1";
		vprint "OPP2 : $opp2";

	}

    for my $div ($dom->find('div.event-view-details__subgroup-content')->each) {
		my $markettype;
		for my $span ($div->find('span')->each) {
#too much
#			vprint "TEXT:" . $span->text;
			$markettype=$span->text;
		}

		my $te=HTML::TableExtract->new( );
	    $te->parse($div);

         # Examine all matching tables
         foreach my $ts ($te->tables)   {
            my $coords=join(',', $ts->coords);
#            vprint "Coords:\"$coords\"\n";
            next unless ($coords == "0,0");
#dump the data
#            foreach my $lrow ($ts->rows) {
#                foreach my $elem (@$lrow) {
#                    $elem =~ s/\s\s*/ /g;
#                    $elem =~ s/^\s\s*//g;
#                    $elem =~ s/\s\s*$//g;
#                    vprint "$elem|";
#                }
#			}
			if ( $markettype eq "1 X 2" ) {
				$market="1";
				$price = bwin_grab($ts->cell(0,0));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
				
				$market="X";
				$price = bwin_grab($ts->cell(0,2));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');

				$market="2";
				$price = bwin_grab($ts->cell(0,4));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
			}
			if ( $markettype eq "Διπλή Ευκαιρία" ) {
				$market="1Χ";
				$price = bwin_grab($ts->cell(0,0));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
				
				$market="Χ2";
				$price = bwin_grab($ts->cell(0,2));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');

				$market="12";
				$price = bwin_grab($ts->cell(0,4));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
			}
			if ( $markettype eq "Θα σκοράρουν στο ματς και οι 2 ομάδες;" ) {
				$market="GG";
				$price = bwin_grab($ts->cell(0,0));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
				
				$market="NG";
				$price = bwin_grab($ts->cell(0,2));
				vprint "MARKET $market PRICE $price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
			}

			if ( $markettype eq "Πόσα γκολ θα σημειωθούν;" ) {
					my $rowcnt=0;	
					foreach my $lrow ($ts->rows) {
						($market,$price)=bwin_grabou($ts->cell($rowcnt,0));
						vprint "MARKET $market PRICE $price" unless ( ! defined($market));
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						($market,$price)=bwin_grabou($ts->cell($rowcnt,2));
						vprint "MARKET $market PRICE $price" unless ( ! defined($market));
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$rowcnt++;
					}
			}
			if ( $markettype eq "Πόσα κόρνερ στο ματς (κανονική διάρκεια)" ) {
					my $rowcnt=0;	
					foreach my $lrow ($ts->rows) {
						($market,$price)=bwin_graboucorner($ts->cell($rowcnt,0));
						vprint "MARKET $market PRICE $price" unless ( ! defined($market));
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						($market,$price)=bwin_graboucorner($ts->cell($rowcnt,2));
						vprint "MARKET $market PRICE $price" unless ( ! defined($market));
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$rowcnt++;
					}
			}


	
	
		} # tables
		
	} #div
 }


#
# Clean up and return a value
#
sub bwin_grab($){
my ($elem)=@_;
	my $ptext = $elem;
	$ptext=trim($ptext);
	$ptext =~ s/\s\s*/ /g;
	vprint "ELEM: $ptext";
	$ptext =~ m/(\d{1,}\.\d{1,})/;
	my $price=$1;
	vprint "preprice: $price";
	return($price);
}



#
# under over 
#
sub bwin_grabou($){
my ($elem)=@_;
my $market;

	my $ptext = $elem;
	$ptext=trim($ptext);

	if ( $ptext =~ /Over/gi ) {
		$market='ΣΥΝΟΛΙΚΟ OVER (%s)';
	} elsif ($ptext =~ /Under/gi ) {
		$market='ΣΥΝΟΛΙΚΟ UNDER (%s)';
	} else {
		return (undef,undef);
	}
	$ptext =~ s/\s\s*/ /g;
	vprint "ELEM: $ptext";

	$ptext =~ m/(\d{1,},\d{1,})/;
	my $ouvalue=$1;
	$ouvalue=~s/,/\./;
	vprint "ouvalue: $ouvalue";

	$ptext =~ m/(\d{1,}\.\d{1,})/;
	my $price=$1;
	vprint "preprice: $price";
	$market=sprintf($market,$ouvalue);
	return($market,$price);
}

#
# under over 
#
sub bwin_graboucorner($){
my ($elem)=@_;
my $market;

	my $ptext = $elem;
	$ptext=trim($ptext);

	if ( $ptext =~ /Over/gi ) {
		$market='ΣΥΝΟΛΙΚΑ ΚΟΡΝΕΡ OVER (%s)';
	} elsif ($ptext =~ /Under/gi ) {
		$market='ΣΥΝΟΛΙΚΑ ΚΟΡΝΕΡ UNDER (%s)';
	} else {
		return (undef,undef);
	}
	$ptext =~ s/\s\s*/ /g;
	vprint "ELEM: $ptext";

	$ptext =~ m/(\d{1,},\d{1,})/;
	my $ouvalue=$1;
	$ouvalue=~s/,/\./;
	vprint "ouvalue: $ouvalue";

	$ptext =~ m/(\d{1,}\.\d{1,})/;
	my $price=$1;
	vprint "preprice: $price";
	$market=sprintf($market,$ouvalue);
	return($market,$price);
}


1;
