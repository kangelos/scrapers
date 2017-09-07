#!/bin/bash

lines=`tail -100 /root/scrapers/nohup.scraper | grep 'No result yet from repl'| wc -l `
if [ $lines -gt 50 ]
then
	echo "Wedged scraper"
	killall -9 scrape.pl
	killall -9 firefox
	nohup /usr/lib64/firefox/firefox --display=:99 -repl  >& /root/scrapers/nohup.firefox  
fi
