#!/bin/bash

appRoot=$(dirname "$0")/..
this=$(readlink -m "$0")
pkgRoot=$(dirname "$this")/..

. "$pkgRoot"/src/sh/taskman.inc.sh

function usage(){
	bye usage: $(basename "$0") some.task 'start|status|stop'
}

#check is running master here allowed
flag=$appRoot/var/master.allowed
[[ -e "$flag" ]] || bye this is not the master host: master flag "$flag" doesnt exist

checkTask "$1"

masterUid=master.$taskUid

action="$2"
case "$action" in
	start)
		#check for another master instance running
		pexists $masterUid && bye another master instance is running. use \'stop\' action to kill it
		
		masterLog="$taskLogs"/master.log 

		#run master
		startTimeout=5
		echo -n starting master with ${startTimeout}s timeout...
		spawn "$taskMaster $masterUid" "$masterLog"

		#wait for some marker is printed into the log when entering the loop().
		#status of the whole block is 0 on match, 1 on timeout
		timeout $startTimeout tail -n+1 -f "$masterLog" | {
			grep -Fqm1 "started $masterUid"
			[[ $? -eq 0 ]] && {
				pkill -P $$ timeout
				$(exit 0)
			}
		}

		[[ $? -ne 0 ]] && {
			echo fail

			#clean up
			kill159 $(pgrep -f $masterUid)

			cat "$masterLog"
			exit
		}
		echo done
	;;
	
	status)
		pexists $masterUid || echo -n "no "
		echo master is running
	;;
	
	stop)
		pexists $masterUid || bye no master is running
		kill159 $(pgrep -f $masterUid)
	;;
	
	*)
		usage
	;;
esac
