#!/usr/bin/perl

use strict;
use utf8;
use Mojo::DOM;


sub vprint($);
sub mybet_scraper_per_game($$$$$);

######################################################################
sub get_mybet_data($$$$){
	my ($category,$url,$verbose,$site) = @_;

	my $firefox = newFirefox();
	my $response=$firefox->get($url);

	my $game="";
	my $market="";
	my $price="";
	my $opp1="";
	my $opp2="";
	my $date="";
	my $time="";
	my $evdate="";
	my %games=undef;

#	my @links = $firefox->selector('a');
#    $firefox->highlight_node(@links);

	vprint "MOJO work\n";
	my $dom=Mojo::DOM->new($firefox->content);
	for my $table ($dom->find('table.betEvent\ eventTable')->each) {
		for my $span ($table->find('span.participants')->each) {
			my $participants=$span->text;
			vprint "GAME:$participants";
			($opp1,$opp2)=split(':',$participants);
		}
		for my $span ($table->find('span.startTime')->each) {
			$evdate=$span->content;
			$evdate=$span;
			$evdate =~ s/^.*content=\"//g;
			$evdate =~ s/\".*$//g;
			my ($date,$t,$dumy)=split('T',$evdate);
			my ($y,$m,$d)=split('-',$date);
			my ($hour,$min,$sec)=split(':',$t);
			$evdate="$d/$m/$y $hour:$min";
			vprint "EVDATE:$evdate";
		}
		$games{"$opp1 v $opp2"}{'date'}=$evdate;

		for my $home ($table->find('td.home1x2')->each) {
			for my $a ($home->find('a.oddsWidth')->each) {
				$market="1";
				$price=$a->text;
				vprint "MARKET: $market price:$price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
			}
		}


		for my $home ($table->find('td.draw1x2')->each) {
			for my $a ($home->find('a.oddsWidth')->each) {
				$market="X";
				$price=$a->text;
				vprint "MARKET: $market price:$price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
			}
		}

		for my $home ($table->find('td.away1x2')->each) {
			for my $a ($home->find('a.oddsWidth')->each) {
				$market="2";
				$price=$a->text;
				vprint "MARKET: $market price:$price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
			}
		}

		my $ou=undef;
		for my $home ($table->find('td.ou')->each) {
			$ou=$home;
			$ou =~ s/<.*?>//g;
			$ou =~ s/<.*?>//g;
			my @lines=split(/\n/,$ou);
			$ou=$lines[1];
		}
		vprint "OU:$ou";

		for my $home ($table->find('td.ouOver')->each) {
			for my $a ($home->find('a.oddsWidth')->each) {
				$market="ΣΥΝΟΛΙΚΟ OVER ($ou)";
				$price=$a->text;
				vprint "MARKET: $market price:$price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
			}
		}


		for my $home ($table->find('td.ouUnder')->each) {
			for my $a ($home->find('a.oddsWidth')->each) {
				$market="ΣΥΝΟΛΙΚΟ UNDER ($ou)";
				$price=$a->text;
				vprint "MARKET: $market price:$price";
				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
			}
		}
		for my $home ($table->find('td.openCloseSwitch')->each) {
			for my $a ($home->find('a.closed')->each) {
				my $href=$a->{href};
				$games{"$opp1 v $opp2"}{'href'}='https://www.mybet.com'.$href;
			}
		}
	}

	return;   # firefox on the VM simply cannot handle this
# this is in trial
#	par_do(\&mybet_scraper_per_game,$category,$site,\%games);

	my @links = $firefox->selector('a.closed');
    $firefox->highlight_node(@links);
	foreach my $link (@links) {
		if ($link->{id} =~ /eventlink/) {
			my $xresponse=$firefox->click({dom=>$link,synchronize=>0});	
		}
	}


	vprint "SECOND PASS";

	# try to grab some data
	for my $table ($dom->find('table')->each) {
		my $title=$table->{betsliptitle};
		next if (! $title);
		vprint "TITLE $title";
		my ($opp1,$opp2)=split(':',$title);
		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";
		my $price=undef;
		my $market=undef;
		my $tip=undef;
		for my $a ($table->find('a.oddsWidth')->each) {
			$price=$a;
			$price =~ s/<.*?>//g;
			$price =~ s/<.*?>//g;

			my $data=$a->{data};
			vprint "DATA $data";
			$data =~ /"marketName":"(.*?)"/;
			my $marketname=$1;
			$marketname=~ s/(\d),(\d)/$1.$2/g;

			my $tipname="";
			my $val="";
			$data =~ /"tip":"(.*?)"/;
			$tip=$1;
			$tip=~ s/(\d),(\d)/$1.$2/g;
			if ( $tip =~ /\s/ ) {
				($tipname,$val)=split(' ',$tip);
			} else {
				$tipname=$tip;
				$val="";
			}

			vprint "MARKET NAME $marketname TIPNAME $tipname";

			if (	$marketname =~ /^Over\/Under \d/gi && $tipname =~ /over/gi) {
				$market = "ΣΥΝΟΛΙΚΟ OVER ($val)";
			} elsif ( $marketname =~ /^Over\/Under \d/gi && $tipname =~ /under/gi) {
				$market = "ΣΥΝΟΛΙΚΟ UNDER ($val)";
			} elsif ( $marketname eq "Διπλή ευκαιρία" && $tipname eq "Home/Draw") {
				$market="1Χ";	# greek chi
			} elsif ( $marketname eq "Διπλή ευκαιρία" && $tipname eq "Home/Away") {
				$market="12";
			} elsif ( $marketname eq "Διπλή ευκαιρία" && $tipname eq "Draw/Away") {
				$market="2Χ";	# greek chi
			}  elsif ( $marketname eq "Θα πετύχουν γκολ και οι δύο ομάδες" && $tipname =~ /Ναι/g) {
				$market="GG";
			}  elsif ( $marketname eq "Θα πετύχουν γκολ και οι δύο ομάδες" && $tipname =~ /Όχι/g) {
				$market="NG";
			} else {
				$market=$marketname . " " . $tipname ; 
				# keep it or not				next;
			}
			
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
		}
	}
}

######################################################################
#
# Football scraping
#
######################################################################
sub  do_mybet_soccer($$$) {
my ($url,$verbose,$site) = @_;
	my $category = "SOCCER";
	get_mybet_data($category,$url,$verbose,$site);
}


######################################################################
#
# BasketBall scraping
#
######################################################################
sub  do_mybet_basket($$$) {
my ($url,$verbose,$site) = @_;
	my $category = "BASKET";
	get_mybet_data($category,$url,$verbose,$site);
}


######################################################################
#
#  per game scraping
#
######################################################################
sub mybet_scraper_per_game($$$$$){
	my ($game,$evdate,$url,$category,$site) = @_;


	my $firefox = newFirefox();
	my $response=$firefox->get($url);
	# second pass
	# open every hidden nook and cranny
	vprint "SECOND PASS\n";
	
	my ($opp1,$opp2)=split(' v ',$game);
	vprint "MOJO work\n";
	my $dom=Mojo::DOM->new($firefox->content);
	for my $table ($dom->find('table')->each) {
		my $title=$table->{betsliptitle};
		next if (! $title);
		vprint "TITLE $title";
		my ($opp1,$opp2)=split(':',$title);
		vprint "OPP1 $opp1";
		vprint "OPP2 $opp2";
		my $price=undef;
		my $market=undef;
		my $tip=undef;
		for my $a ($table->find('a.oddsWidth')->each) {
			$price=$a;
			$price =~ s/<.*?>//g;
			$price =~ s/<.*?>//g;

			my $data=$a->{data};
			vprint "DATA $data";
			$data =~ /"marketName":"(.*?)"/;
			my $marketname=$1;
			$marketname=~ s/(\d),(\d)/$1.$2/g;

			my $tipname="";
			my $val="";
			$data =~ /"tip":"(.*?)"/;
			$tip=$1;
			$tip=~ s/(\d),(\d)/$1.$2/g;
			if ( $tip =~ /\s/ ) {
				($tipname,$val)=split(' ',$tip);
			} else {
				$tipname=$tip;
				$val="";
			}

			vprint "MARKET NAME $marketname TIPNAME $tipname";

			if (	$marketname =~ /^Over\/Under \d/gi && $tipname =~ /over/gi) {
				$market = "ΣΥΝΟΛΙΚΟ OVER ($val)";
			} elsif ( $marketname =~ /^Over\/Under \d/gi && $tipname =~ /under/gi) {
				$market = "ΣΥΝΟΛΙΚΟ UNDER ($val)";
			} elsif ( $marketname eq "Διπλή ευκαιρία" && $tipname eq "Home/Draw") {
				$market="1Χ";	# greek chi
			} elsif ( $marketname eq "Διπλή ευκαιρία" && $tipname eq "Home/Away") {
				$market="12";
			} elsif ( $marketname eq "Διπλή ευκαιρία" && $tipname eq "Draw/Away") {
				$market="2Χ";	# greek chi
			}  elsif ( $marketname eq "1X2 και Γκολ και οι δύο ομάδες" && $tipname =~ / \& Ναι/g) {
				$market="GG";
			}  elsif ( $marketname eq "1X2 και Γκολ και οι δύο ομάδες" && $tipname =~ / \& Όχι/g) {
				$market="NG";
			} else {
				$market=$marketname . " " . $tipname ; 
				# keep it or not				next;
			}
			
			vprint "MARKET $market PRICE $price";
			domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
		}
	}

	my @links = $firefox->selector('a');
#    $firefox->highlight_node(@links);

	#	after we are done we must close the link
	foreach my $link (@links) {
		if (($link->{id} =~ /eventlink/) && ($link->{class} !~ /closed/ )) {
			my $xresponse=$firefox->click({dom=>$link,synchronize=>0});	
		}
	}
}

1;
