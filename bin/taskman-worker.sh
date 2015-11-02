#!/bin/bash

appRoot=$(dirname "$0")/..
this=$(readlink -m "$0")
pkgRoot=$(dirname "$this")/..

. "$pkgRoot"/src/sh/taskman.inc.sh

function usage(){
	bye usage: $(basename "$0") some.task 'limit N|status'
}

function killWorkers(){
	local phPids=() pid shPid
	for pid in $@; do
		shPid=$(pgrep -fP $pid 'sh -c softlimit')
		[[ $? -eq 0 ]] && {
			phPid=$(pgrep -P $shPid phantomjs)
			[[ $? -eq 0 ]] && {
				phPids+=($phPid)
			}
		}
	done

	kill159 $@
	
	echo killing abandoned phantomjs instances
	[[ ${#phPids[@]} -gt 0 ]] && kill ${phPids[@]} 2>/dev/null
}

checkTask "$1"

workerUid=worker.$taskUid
running=$(pcount $workerUid)

action="$2"
case "$action" in
	limit)
		N="$3"
		[[ "$N" =~ ^[0-9]+$ ]] || bye limit requires an uint argument

		if [[ $N -gt 0 ]]; then
			[[ $N -eq $running ]] && bye there are exactly $N workers running

			if [[ $N -gt $running ]]; then
				((delta=N-running))
				echo -n spawning $delta more workers...
				for ((i=1;i<=delta;i++)); do
					spawn "$taskWorker $workerUid" "$taskLogs"/worker.$$-$i.log
				done
				echo done
			else
				((delta=running-N))
				killWorkers $(pgrep -f $workerUid | head -n$delta)
			fi
		else
			[[ $running -eq 0 ]] && bye no workers are running
			killWorkers $(pgrep -f $workerUid)
		fi
	;;
	
	status)
		echo workers: $running
	;;
	
	*)
		usage
	;;
esac
