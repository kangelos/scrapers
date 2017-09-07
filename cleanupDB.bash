#!/bin/bash

# any data older than two months is not useful to us any more
INTERVAL=60

#is the param a number ?
if [ "$1" -eq "$1" ] 2>/dev/null; then
	# safety check we absolutely need two weeks data
	if  [ $1 -gt 15 ]  ; then
		INTERVAL=$1
	fi
fi

echo "delete from bets where eventdate<DATE_SUB(CURDATE(),INTERVAL $INTERVAL DAY);" | mysql bets
echo "delete from changes where eventdate<DATE_SUB(CURDATE(),INTERVAL 7 DAY);" | mysql bets
