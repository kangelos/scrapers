#!/bin/bash


SITES="novibet goalbet betshop 1xbetcy opap stoiximan bet365 mybet sportingbet bwin"

DISPLAY=:99
VERBOSE="--verbose"
#DEBUG="--debug" # only for debugging

# firefox cannot handle more than 3
TABS=3


function run_group {
	for site in $*
	do
		# just making sure it does not go crazy
		/usr/bin/timeout 1h /root/scrapers/scrape.pl --site=${site} --tabs=$TABS $VERBOSE $DEBUG
		clean_tabs
		sleep 10
	done
}

function clean_tabs {
	#close any leftover tabs
	for i in 1 2 3
	do
		/usr/bin/timeout 5 /usr/bin/nc localhost 4242 << "JS" >& /dev/null

			window.getBrowser().removeCurrentTab()
			repl.quit()

JS
	done
}

while [ 1 ]
do
	run_group $SITES
	sleep  60
done
