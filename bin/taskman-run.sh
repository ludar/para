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

	bin/taskman-worker.sh "$task" limit $N
	bin/taskman-master.sh "$task" start

else
	echo previous instance is still running or runtime error
	echo [M status] $ms
	echo [W status] $ws
fi
