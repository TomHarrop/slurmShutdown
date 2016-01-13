#!/bin/bash

set -u

# make sure we are root
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

# run shutdown job with srun and wait for it to exit 0
echo -e "[ "$(date)" : submitting shutdownJob2 with srun ]"
cmd="/home/tom/Projects/slurmShutdown/shutdownJob2.sh"
while ! srun --cpus-per-task=8 \
	--nice=1000 \
	--exclusive \
	--mail-type=ALL \
	--job-name="shutdown" \
	--output="/var/log/slurmShutdown/log.job.txt" \
	"$cmd" ; do
	sleep 1m
	echo -e "[ "$(date)" : shutdownJob2 failed, resubmitting ]"
done

# if shutdownJob2 has exit state of 0 it is safe to shutdown
echo -e "[ "$(date)" : shutdownJob2 succeeded, proceeding with shutdown ]"
cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job completed" tom
	Shutdown point reached in SLURM queue; performing shutdown.
_EOF_
poweroff
exit 0
