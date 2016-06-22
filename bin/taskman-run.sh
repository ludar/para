#!/bin/bash

#It runs workers + master ON THE SAME SERVER ONLY!!

appRoot=$(dirname "$0")/..
this=$(readlink -m "$0")
pkgRoot=$(dirname "$this")/..

. "$pkgRoot"/src/sh/taskman.inc.sh

function usage(){
	bye usage: $(basename "$0") taskName workersNumber
}

task="$1"
[[ "$task" ]] || usage
task=task/"$task".task

N="$2"
isInt "$N" || bye workersNumber should be an uint

cd $appRoot

ms=$(bin/taskman-master.sh "$task" status)
ws=$(bin/taskman-worker.sh "$task" status)

if [[ "$ms" == "no master is running" && "$ws" == "workers: 0" ]]; then

	# It is best to keep the order: workers first, master next. Otherwise workers
	# won't quit in case there are no tasks.

	bin/taskman-worker.sh "$task" limit $N

	# Sometimes master cant start but workers keep running so it prevents the master
	# from running on next invokation at all. The problem appeared somewhere in Apr to May 2016.
	# Probably it is related to the "start a bunch of workers" +
	# "immediately start the master with 5 secs timeout".
	# Increasing master start timeout is not reliable (it has no access to the number
	# of workers that has just been run).
	# Let's try introduce N/2 secs pause here.
	((pause=N/2))
	echo waiting $pause secs for workers to get ready
	sleep $pause

	bin/taskman-master.sh "$task" start

else
	echo previous instance is still running or runtime error
	echo [M status] $ms
	echo [W status] $ws
fi
