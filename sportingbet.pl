#!/usr/bin/perl

######################################################################
#
#  sportingbet scraping
#
######################################################################
use strict;
use utf8;
use Switch;
use Mojo::DOM;

sub scrape_sportingbet_per_game($$$$$);

######################################################################
#
# FootBall scraping
#
######################################################################
sub  do_sportingbet_soccer($$$) {
my ($url,$verbose,$site) = @_;

	my $game="";
	my $market="";
	my $price="";
	my $opp1="";
	my $opp2="";
	my $date="";
	my $time="";
	my $evdate="";
	my $href="";

	my %games;
	my $category = "SOCCER";
	my $firefox = newFirefox();  

	my $response=$firefox->get($url);
#	sleep(2);
	# Find today's soccer link
	foreach my $selector ( $firefox->selector('a')) {
			my $inner= $selector->{innerHTML};
			my $id = $selector->{id};
			if ( $inner =~ /ΑΓΩΝΕΣ ΗΜΕΡΑΣ/ ) {
				$firefox->click($selector);
				sleep(5);
				last;
			}
	}
	my $html=$firefox->content();
	# speeds thigs up for testing only
	#	my $html=read_data('/tmp/sportingbet.html');


	my $dom=Mojo::DOM->new($html);
	my $score="";
	for my $top ($dom->find('div.couponEvents')->each) {
			for my $eventactive ($top->find('div.event\ active')->each) {
					for my $li  ($eventactive->find('div.eventInfo')->each ) {

						for my $eventname ($li->find('div.eventName')->each) {
								for my $a ($eventname->find('a.eventNameLink')->each) {
									$game = $a->{title};
									$href=$a->{href};
									$games{$game}{'href'}=$href;
									# get rid of multiple spaces
									$game =~ s/ [ ]*/ /gi;
								}
						}
						# this is mute, not used for now
						for $score ($li->find('span.score')->each) {
							$score =~ s/<.*?>//g;
							$score =~ s/<.*?>//g;
							$score =~ s/\s//g;
						}
						for my $starttime ($li->find('span.StartTime')->each) {
								$starttime =~ s/<.*?>//g;
								$starttime =~ s/<.*?>//g;
								$starttime =~ s/ .*//g;
								$evdate=$starttime;
								$games{$game}{'date'}=$evdate;
						}

						

					}	
			# prices start here !

					for my $selection ($eventactive->find('div.selections\ active')->each) {
						my $count=0;
						for my $input ($selection->find('input.decValue')->each) {
							$price=$input->{value};
							switch ($count) {
								case "0" {
									$market="1";
								}	
								case "1" {
									$market="X";
								}
								case "2" {
									$market="2";
								}
							}
							vprint $game . " " . $time .  " " . $market . " " . $price ;
							$count++;
							my ($opp1,$opp2)=split(' v ',$game);
							domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
						}
					}

			}
	}

# top level page done

	undef $firefox;
	par_do(\&scrape_sportingbet_per_game,$category,$site,\%games);
}


######################################################################
#
# basket scraping
#
######################################################################
sub  do_sportingbet_basket($$$) {
my ($url,$verbose,$site) = @_;

	my $game="";
	my $market="";
	my $price="";
	my $opp1="";
	my $opp2="";
	my $date="";
	my $time="";
	my $evdate="";
	my $href="";

	my %games;
	my $category = "BASKET";
	my $firefox = newFirefox();

	my $response=$firefox->get($url);
#	sleep(2);
	# Find today's soccer link
	foreach my $selector ( $firefox->selector('a')) {
			my $inner= $selector->{innerHTML};
			my $id = $selector->{id};
			if ( $inner =~ /Μπάσκετ/ ) {
				$firefox->click($selector);
				sleep(5);
				last;
			}
	}
	my $html=$firefox->content();
	# speeds thigs up for testing only
	#	my $html=read_data('/tmp/sportingbet.html');


	my $dom=Mojo::DOM->new($html);
	my $score="";
	for my $top ($dom->find('ul.couponEvents')->each) {
			for my $eventactive ($top->find('li.event\ active')->each) {
					for my $li  ($eventactive->find('li.eventInfo')->each ) {

						for my $eventname ($li->find('div.eventName')->each) {
								for my $a ($eventname->find('a.eventNameLink')->each) {
									$game = $a->{title};
									$href=$a->{href};
									$games{$game}{'href'}=$href;
									# get rid of multiple spaces
									$game =~ s/ [ ]*/ /gi;
								}
						}
						# this is mute, not used for now
						for $score ($li->find('span.score')->each) {
							$score =~ s/<.*?>//g;
							$score =~ s/<.*?>//g;
							$score =~ s/\s//g;
						}
						for my $starttime ($li->find('span.StartTime')->each) {
								$starttime =~ s/<.*?>//g;
								$starttime =~ s/<.*?>//g;
								$starttime =~ s/ .*//g;
								$evdate=$starttime;
								$games{$game}{'date'}=$evdate;
						}

						

					}	
			# prices start here !

					for my $selection ($eventactive->find('li.selections\ active')->each) {
						my $count=0;
						for my $input ($selection->find('input.decValue')->each) {
							$price=$input->{value};
							switch ($count) {
								case "0" {
									$market="1";
								}	
								case "1" {
									$market="2";
								}
							}
							vprint $game . " " . $time .  " " . $market . " " . $price ;
							$count++;
							my ($opp1,$opp2)=split(' v ',$game);
							domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
						}
					}

			}
	}

# top level page done

	undef $firefox;
	par_do(\&scrape_sportingbet_per_game,$category,$site,\%games);
}



######################################################################
#
# Scrape each game
#
######################################################################
sub scrape_sportingbet_per_game($$$$$){
my ($game,$evdate,$url,$category,$site) = @_;

	my $market="";
	my $price="";
	my ($opp1,$opp2)	= split(' v ',$game);

#	vprint "-----------------   game:$game -----------" .  " \n" ;
#	vprint "-----------------   opp1:$opp1 -----------" .  " \n" ;
#	vprint "-----------------   opp2:$opp2 -----------" .  " \n" ;
#	vprint "-----------------   date:$evdate -----------" .  " \n" ;
	vprint "SCRAPING GAME $game DATE $evdate";


	my $firefox = newFirefox();
	my $response=$firefox->get($url);
#	sleep(5);

	my $html=$firefox->content();
	my $dom=Mojo::DOM->new($html);

	for my $top ($dom->find('ul.markets-list')->each) {
		my $mname="";
		my $mkt="";
		for my $span ($top->find('span.headerSub\ groupHeader')->each) {
			$mname=$span;
			$mname =~ s/<.*?>//g;
			$mname =~ s/^\s[\s]*//g;
			$mname =~ s/\s[\s]*$//g;

			if ( $mname eq 'Συνολικά Γκολ αγώνα') {
				$mname="ΣΥΝΟΛΙΚΟ"
			}
		}

		# this is only for over under
		for my $li ($top->find('li.opened')->each)  {
				for my $half ($li->find('div.half')->each) {
					for my $desc ($half->find('li.description\ opened')->each) {
						my $market = $desc;
						
						$market =~ s/<.*?>/ /g;
						$market =~ s/(\d+\.\d+)/\(\1\) /g;

						$mkt=$mname . " " . $market;
						$mkt =~ s/\s\s*/ /g; # too many spaces ?
					}

					for my $results ($half->find('li.results\ opened')->each) {
#vprint "RESULTS:".$results;
						for my $input ($results->find('input.decValue')->each) {
							$price=$input->{value};
							vprint  "MARKET $mkt Price:$price";
							if ( $mkt =~ /^Σύνολο Πόντων Over \(/ ) {
								$mkt =~ s/^Σύνολο Πόντων Over/ΣΥΝΟΛΙΚΟ OVER/g;
							}
							if ( $mkt =~ /^Σύνολο Πόντων Under \(/ ) {
								$mkt =~ s/^Σύνολο Πόντων Under/ΣΥΝΟΛΙΚΟ UNDER/g;
							}
							domysql($site,$evdate,$opp1,$opp2,$category,$mkt,$price,1,"-");
						}
					}
				}
		}

#		# some of the stuff for goal no goal
#		for my $li ($top->find('li.couponHeader\ opened')->each)  {
#			for my $ev ($li->find('div.m_event')->each)  {
#				for my $desc ($ev->find('div.description')->each) {
#					$desc =~ s/<.*?>/ /g;
#					$market=$desc;
#					
#				}
#				for my $res ($ev->find('div.results')->each) {
#						for my $input ($res->find('input.decValue')->each) {
#							$price=$input->{value};
#						}
#				}
#			}
#			if ( myuc($market,1) ne myuc($game,1) ) {
#				domysql($site,$evdate,$opp1,$opp2,$category,$market,$price,1,"-");
#			}
#		}

		
	}
#	undef $firefox;
}


1;
