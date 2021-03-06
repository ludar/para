function bye(){
	echo "$@"
	exit
}
function spawn(){
	rm -f "$2"
	#ensure the log exists right after spawn invocation
	touch "$2"
	$1 >"$2" 2>&1 &
}

function pcount(){
	pgrep -fc "$1"
}

function pexists(){
	[[ $(pcount "$1") -gt 0 ]]
}

#kill with signal 15, wait some (based on processes number) secs, kill with signal 9
function kill159(){
	[[ -z "$@" ]] && return

	#pause is scaled 2..40 secs
	local pauseFloat=$(awk "{print 40*atan2($#,100)/atan2(1,0)}" <<< "")
	local pause=${pauseFloat/.*/}
	[[ $pauseFloat =~ \.0+$ ]] || ((pause+=1))
	[[ $pause -lt 2 ]] && pause=2

	echo killing $# processes with SIGTERM
	kill $@
	echo -n waiting $pause secs...
	sleep $pause
	echo done

	local pid
	for pid in $@; do
		if kill -0 $pid 2>/dev/null; then
			echo killing still running pid $pid with SIGKILL
			kill -9 $pid
		fi
	done
}

function checkTask(){
	#check task filename
	local task="$1"
	[[ -z "$task" ]] && usage
	[[ ! -f "$task" || ! -r "$task" ]] && bye task must be a readable file

	. "$task"

	#check task vars
	[[ ! "$taskUid" =~ ^[a-z0-9]{32}$ ]] && bye @taskUid var mush look like some md5 hash
	[[ -z "$taskMaster" || -z "$taskWorker" ]] && bye @taskMaster and @taskWorker vars must be set
	
	#check logs dir. $taskLogs goes global!!
	taskLogs="$appRoot"/var/log/$taskUid
	if [[ -e "$taskLogs" ]]; then
		[[ ! -d "$taskLogs" ]] && bye "$taskLogs" already exists and is a file
		[[ ! -w "$taskLogs" ]] && bye "$taskLogs" already exists and is not writable
	else
		mkdir -p "$taskLogs" 2>/dev/null || bye cant create "$taskLogs"
	fi
}

function isInt(){
	[[ "$1" =~ ^[0-9]+$ ]]
}
