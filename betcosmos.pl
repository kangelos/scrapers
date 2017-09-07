#!/usr/bin/perl

use strict;
use utf8;
use LWP::Simple;
use LWP::UserAgent;


######################################################################
#
#   generic stuff
#
######################################################################
sub betcosmos_parse_results($$$) {
my ($content,$verbose,$category) =@_;
# update with the finals and results
 my $re=HTML::TableExtract->new( );
 $re->parse($content);

 # Examine all matching tables
 my $eventdate="";
 foreach my $ts ($re->tables) 	{
	#vprint "Table (". join(',', $ts->coords) .  "):\n" if ( $verbose);
	my $coords=join(',', $ts->coords);
	next unless ($coords eq "3,1");
	# print the entries out
	getrows($ts,$verbose);

	my $first=0;
	foreach my $lrow ($ts->rows) {
		# skip the header line
		my @row=@$lrow;

		if ($row[0] =~ /(\d\d)\/(\d\d)\/(\d\d\d\d)/g ) {
			$eventdate="$3-$2-$1";
			next;
		}
		my $couponid	= $row[1];
		my $opp2		= $row[5];
		my $scorehalf	= $row[12];
		my $result		= $row[13];
		my $res			= $row[14];
		my $scorefull	= $result;
#		scoreupdate_by_couponid('opap',$couponid,$eventdate,$res,$scorehalf,$scorefull);
		scoreupdate_by_opp2('opap',$opp2,$eventdate,$res,$scorehalf,$scorefull);
		
	}
  }
}

######################################################################
#
# We get the scores from betcosmos
#
######################################################################
sub  do_betcosmos_scores($$) {
my ($url,$verbose) = @_;

	# use this are reference
	my $category="SOCCER";

 
 my $ua = LWP::UserAgent->new;
 $ua->timeout(30);
 $ua->env_proxy;
 
 my $response = $ua->get($url);
 
 if ($response->is_success) {
     betcosmos_parse_results( $response->decoded_content,$verbose,$category);
 } else {
     die $response->status_line;
 }
}

1;
