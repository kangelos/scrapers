#!/bin/bash
cd /root/scrapers


#DEBUG=""
DEBUG="--debug"

#VERBOSE=""
VERBOSE="--verbose"

# firefox cannot handle more than 3
TABS=2

lockfile="/tmp/lock.ONEMASTER"

if ( set -o noclobber; echo "locked by $$" > "$lockfile") 2> /dev/null; then
	trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT KILL STOP
#  echo "Locking succeeded" >&2
else
		
	echo "Lock failed - exit" >&2
	exit 1
fi

/bin/echo -n "Starting:" && date

# is firefox up ?
/root/scrapers/restart.bash

# vistabet runs from crontab
for site in opap  stoiximan 1xbetcy sportingbet vistabet
do
	echo "======================================== running site $site ============================"
	time /root/scrapers/scrape.pl --site=${site}  --tabs=${TABS}  $VERBOSE $DEBUG  2>&1 | grep -v "Wide chara" 
done


/bin/echo -n "Ending:" && date
