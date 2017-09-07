#!/bin/bash
#
#
# updated game results and in the process check that firefox is OK
#
#


function clobber {
    initctl stop firefox
	initctl restart Xvnc
    sleep 5
    initctl start firefox
}

cd /root/scrapers
/usr/bin/timeout 300 /root/scrapers/scrape.pl --nosyslog --verbose --debug --site=betcosmos --timeout=260>& /tmp/test
if [ $? == 124 ]
then
	echo "Scraper timed out, restarting Firefox"
	clobber
fi

grep "Failed to connect"  /tmp/test
if [ $? == 0 ]
then
	echo "Firefox wedged , restarting"
	clobber
fi

grep "TypeError: this.selectedItem is null" /tmp/test
if [ $? == 0 ]
then
    echo "Firefox wedged , restarting"
	clobber
fi
