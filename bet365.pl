#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;


sub bet365_scrape_per_game($$$$$);
sub bet365_scrape_top_page($$$$);

#globals, careful when threading
our $sleep=4;
my %MONTHS= (
	'Ιαν' => '01',
	'Φεβ' => '02',
	'Μαρ'	=> '03',
	'Απρ'	=> '04',
	'Μαι'	=> '05',
	'Ιουν'	=> '06',
	'Ιουλ'	=> '07',
	'Αυγ'	=> '08',
	'Σεπ'	=> '09',
	'Οκτ'	=> '10',
	'Νοε'	=> '11',
	'Δεκ'	=> '12'
);

######################################################################
#
# FootBall scraping
#
######################################################################
sub  do_bet365_euro($$$) {
my ($url,$verbose,$site) = @_;

	my $category = "SOCCER";
	my $firefox = newFirefox();
	my $response=$firefox->get($url);
	sleep($sleep);

	foreach my $selector ( $firefox->selector('span')) {
		my $id = $selector->{id};
		my $inner= $selector->{innerHTML};
		if ( $inner =~ /Euro 2016/ ) {
			$firefox->click({dom=>$selector,synchronize=>0});
			sleep($sleep);
		}
	}

	my $html=$firefox->content();
	bet365_scrape_top_page($site,$category,$html,$url);
}

######################################################################
#
# FootBall scraping
#
######################################################################
sub  do_bet365_soccer($$$) {
my ($url,$verbose,$site) = @_;

	my $category = "SOCCER";
	my $firefox = newFirefox();
	my $response=$firefox->get($url);
	sleep($sleep);

# no need to find the link , it is passed from the command line 	
#	my $xselector=undef;
#	foreach my $selector ( $firefox->selector('span')) {
#		my $id = $selector->{id};
#		my $inner= $selector->{innerHTML};
#		vprint "SELECTOR $inner";
#		if ( $inner =~ /Ποδόσφαιρο$/gi ) {
#			$xselector=$selector;
#		}
#	}
#
#	if ( ! $xselector ) {
#		vprint "Could not locate link Ποδόσφαιρο\n";
#		return;
#	}
#	vprint "Found /Ποδόσφαιρο/";
#	$firefox->click({dom=>$xselector,synchronize=>0});
#	sleep($sleep);

	for my $what ('Ευρωπαϊκό Κουπόνι','Κουπόνι Φιλικών Συλλόγων') {
		my $xselector=undef;
		foreach my $selector ( $firefox->selector('span')) {
			my $id = $selector->{id};
			my $inner= $selector->{innerHTML};
			if ( $inner =~ /$what/gi ) {
				$xselector=$selector;
			}
		}

		if ( ! $xselector) {
			vprint "ERROR NOT FOUND /Αγώνες/ EXITING";
			return;
		}
		vprint "Found /Αγώνες/";
		$firefox->click({dom=>$xselector,synchronize=>0});
		sleep($sleep);

		my $html=$firefox->content();
		bet365_scrape_top_page($site,$category,$html,$url);
	}
}


######################################################################
#
# Games listing page is common
#
#
######################################################################
sub bet365_scrape_top_page($$$$) {
my ($site,$category,$html,$url)=@_;
	my $dom=Mojo::DOM->new($html);
	my $score="";
	my $opp1="";
	my $opp2="";
	my $gametime="";
	my $evdate="";
	my %games;

	my $nav="";
	vprint "TOP PAGE";
	for my $div ($dom->find('div')->each) {
		my $class=$div->{class};
		next unless ($class =~ /podEventRow\s\s*.*?\s\s*ippg-Market/);
		vprint "CLASS $class\n";
		$div =~ m/data-nav=\"rw_.*,MarketCount,(.*?),/gmx;
		$nav=$1;
		vprint "NAV $nav";
		my $gametime="";
		for my $top ($div->find('div.ippg-Market_GameDetail')->each) {
			$opp1="";
			$opp2="";
			for my $opponent ($top->find('span.ippg-Market_Truncator')->each) {
				if ( $opp1 eq "" ) {
					$opp1=$opponent;
					$opp1=~ s/<.*?>//g;
					$opp1=~ s/<.*?>//g;
				} else {
					$opp2=$opponent;
					$opp2=~ s/<.*?>//g;
					$opp2=~ s/<.*?>//g;
				}
			}
			vprint "OPP1 $opp1\n";
			vprint "OPP2 $opp2\n";
			for my $time ($top->find('div.ippg-Market_GameStartTime')->each) {
					$gametime=$time;
					$gametime=~ s/<.*?>//g;
            		$gametime=~ s/<.*?>//g;
					vprint "GAMETIME $gametime\n\n\n";
				}
		}

		$evdate=$gametime;
		my $game=${opp1}." v ".${opp2};
		$games{$game}{'date'}	= $evdate;
		$games{$game}{'href'}	=  'https://mobile.bet365.gr/#type=MarketCount;key=' . $nav . ';ip=0;lng=20';
	}

	# top level page done
	# now do in parallel every game
	par_do(\&bet365_scrape_per_game,$category,$site,\%games);
}



######################################################################
#
# Each game
#
######################################################################
sub bet365_scrape_per_game($$$$$){
	my ($game,$evtime,$href,$category,$site) = @_;

	my $market="";
	my $category="";
	my $price="";
	my $class;
	my $category		= "SOCCER";
	my ($opp1,$opp2)	= split(/ v /,$game);

	vprint "SCRAPING GAME $game TIME $evtime";


	my $firefox = newFirefox();
	my $response=$firefox->get($href);
	sleep($sleep);


	# from this point onwards its Mojo::DOM
	# Just Over Under section
	my %markets;
	my $market="";
	my $price="";
	my $em="";
	my $subem="";
	my $evdate="";

	my $dom=Mojo::DOM->new($firefox->content);
	my $year=sprintf( "%4d",localtime->year() + 1900);
	for my $div ($dom->find('div')->each) {
		my $class=$div->{class};
		next unless ( $class =~ /secondaryHeaderCel/);
		#vprint "DATEDIV $div";
		$evdate=$div;
		vprint "EVDATE $evdate";
		$evdate=~ s/<.*?>//gi;
		$evdate=~ s/<.*>//gi;
		foreach my $mon (keys %MONTHS) {
			$evdate=~ s/$mon/$MONTHS{$mon}/gi;
		}
		my ($day,$mon,$time)=split(' ',$evdate);
		$evdate=sprintf( "%02d/%02d/%4d %s",$day, $mon,$year,$time);
		vprint "EVDATE $evdate";
	
	}

	for my $div ($dom->find('div.enhancedPod\ matchBetting')->each) {
		#	vprint "DIV " . $div ;
			vprint "CLASS " . $div->{class} ;
			if ($div =~ m/<em>(.*)<\/em>/gmx) {
				$em=$1;
			}
			for my $row ($div->find('div.podEventRow\ singleRow')->each) {
				$subem="";
				my $overcnt=0;
				for my $subdiv ($row->find('div')->each) {
					if ($subdiv =~ m/<em>(.*)<\/em>/gmx) {
						$subem=$1;
					}
				#	vprint "=================";
				#	vprint "EM $em";
				#	vprint "SUBEM $subem";
					vprint "EM $em SUBEM $subem SUBDIV $subdiv";
					if ( $em =~ /Διαφορές Νίκης/ ) {
						vprint "BAD MARKET $em";
						next;
					}

					if ( $em =~ /Over\/Under/ ) {
						if ( $overcnt == 0 ) {
							$overcnt++;
							next;
						}
						$price=$subdiv;
						$price =~ s/<.*?>//gi;
						$price =~ s/<.*?>//gi;
						if ( $overcnt == 1 ) {
							$market="ΣΥΝΟΛΙΚΟ OVER ($subem)";
						}
						if ( $overcnt == 2 ) {
							$market="ΣΥΝΟΛΙΚΟ UNDER ($subem)";
						}
						vprint "EM $em SUBEM $subem MARKET $market PRICE $price OVERCNT $overcnt";
						domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
						$overcnt++;
						next;
					}

					for my $span ($subdiv->find('span.opp')->each) {
						$market=$span;
						$market=~ s/<.*?>//g;
						$market=~ s/<.*?>//g;
					}
					for my $span ($subdiv->find('span.odds')->each) {
						$price=$span;
						$price=~ s/<.*?>//g;
						$price=~ s/<.*?>//g;
					}
					vprint "EM $em MARKET $market PRICE $price";

					if ( $em =~ /Να Σκοράρουν Και Οι Δύο Ομάδες/gi ) {
						if ($market =~ /Ναι/gi ) {
							$market="GG";
						}
						if ($market =~ /Όχι/gi ) {
							$market="NG";
						}
					}elsif ( $market eq "1X" ) {
						$market="1Χ";
					}elsif ( $market eq "X2" ) {
						$market="Χ2";
					}
					vprint "EM $em SUBEM $subem MARKET $market PRICE $price OVERCNT $overcnt";
					if ($market =~ /^[+-]\d+\.\d+/) {
						vprint "INVALID MARKET $market";
						next;
					}
					domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,'');
				}
			}
		}
#	undef $firefox;

}


######################################################################
#
# Basket scraping
#
######################################################################
sub  do_bet365_basket($$$) {
my ($url,$verbose,$site) = @_;
	my $category = "BASKET";
	my $firefox = newFirefox();
	my $response=$firefox->get($url);
	my $html=$firefox->content();
	bet365_scrape_top_page($site,$category,$html,$url);
}

1;
