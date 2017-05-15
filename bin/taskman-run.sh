#!/bin/bash

#It runs workers + master ON THE SAME SERVER ONLY!!

appRoot=$(dirname "$0")/..
this=$(readlink -m "$0")
pkgRoot=$(dirname "$this")/..

. "$pkgRoot"/src/sh/taskman.inc.sh

function usage(){
	bye usage: $(basename "$0") '--task <task> --workers <int> [--reuse-workers]'
}

args=$(getopt -o '' -l workers:,task:,reuse-workers -- "$@")
if [[ $? -ne 0 ]]; then
	exit
fi

eval set -- "$args"

reuse_workers=no
while true; do
	case "$1" in
		--)
			shift
			break
			;;
		--reuse-workers)
			reuse_workers=yes
			shift
			;;
		*)
			eval ${1#--}=$2
			shift 2
			;;
	esac
done

[[ "$task" ]] || usage
task=task/"$task".task

isInt "$workers" || bye --workers value should be int

cd $appRoot

ms=$(bin/taskman-master.sh "$task" status)
if [[ "$ms" == "no master is running" ]]; then
	wc=$(bin/taskman-worker.sh "$task" status | cut -d' ' -f2)

	if [[ $wc -eq 0 || $reuse_workers == yes ]]; then
		# It is best to keep the order: workers first, master next. Otherwise workers
		# won't quit in case there are no tasks.

		bin/taskman-worker.sh "$task" limit $workers

		# Sometimes master cant start but workers keep running so it prevents the master
		# from running on next invokation at all. The problem appeared somewhere in Apr to May 2016.
		# Probably it is related to the "start a bunch of workers" +
		# "immediately start the master with 5 secs timeout".
		# Increasing master start timeout is not reliable (it has no access to the number
		# of workers that has just been run).
		# Let's try introduce workers/2 secs pause here.
		((pause=workers/2))
		echo waiting $pause secs for workers to get ready
		sleep $pause

		bin/taskman-master.sh "$task" start
	else
		echo there are workers running already. Use --reuse-workers switch to reuse them.
	fi

else
	echo previous instance of master is still running or runtime error
	echo [M status] $ms
fi
