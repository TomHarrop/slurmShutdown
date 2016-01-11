#!/bin/bash

set -eu

# make sure we have root
if [[ $EUID -ne 0 ]]; then
	cat <<- _EOF_ | mail -s "[Tom@SLURM] UNABLE TO RUN shutdown job" tom
	Shutdown wrapper was not submitted as root.
_EOF_
	exit 1
fi

# catch interruptions
clean_up() {
	cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown wrapper EXITED" tom
	Shutdown wrapper exited at $(date).
_EOF_
	exit 1
}
trap clean_up SIGHUP SIGINT SIGTERM

# make log dir
logdir="/var/log/slurmShutdown"
if [[ -d "$logdir" ]]; then
	mkdir -p "$logdir"
fi

# check / remove leftover flags
shopt -s nullglob
leftovers=(""$logdir"/*.flag")
for flagfile in "$leftovers"
do
	if [[ -e "$flagfile" ]]; then
		echo -e "[ "$(date)" : removing leftover flag file "$flagfile" ]" >> "$logdir/log.wrapper.txt"
		rm "$flagfile"
	fi
done
shopt -u nullglob

# enter loop if jobRun doesn't exist
while [[ ! -e "$logdir/jobRun.flag" ]]; do

	# submit shutdown job
	sbatch shutdownJob.sh 2>&1 | mail -s "[Tom@SLURM] Shutdown job submitted" tom
	
	# wait for jobRun to appear
	while [[ ! -e "$logdir/jobRun.flag" ]]; do
		sleep 1m
	done

	# once jobRun appears, start jobFail/jobFinish loop
	# while jobFail doesn't exist
	while [[ ! -e "$logdir/jobFail.flag" ]]; do
		# look for jobFinished
		if [[ -e  "$logdir/jobFinished.flag" ]]; then
			# if jobFinished exists, remove it and exit happily
			rm ""$logdir"/jobFinished.flag"
			cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job running on SLURM" tom
				Shutdown job has been launched by SLURM; wrapper is exiting.
_EOF_
			exit 0
		fi
		# otherwise wait 1m and check both files again
		sleep 1m
	done
done