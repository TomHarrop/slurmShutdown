#!/bin/bash

logdir="/var/log/slurmShutdown"

# catch interruptions
clean_up() {
	cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job $SLURM_JOBID CANCELLED" tom
	Shutdown requested with JobID $SLURM_JOBID was cancelled at $(date).
_EOF_
	exit 1
}
trap clean_up SIGHUP SIGINT SIGTERM

# when job starts, wait and check queue in case other jobs were added
sleep 1m

# if jobs were added
if [[ $(squeue -a | wc -l) -gt 2 ]]; then
	# exit 1 and mail notification
	cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job $SLURM_JOBID did not run" tom
	Shutdown requested with JobID $SLURM_JOBID did not run because other jobs were submitted.

	$(squeue -a)
_EOF_
	exit 1
fi

# otherwise, queue is empty. email notification and exit 0
cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job $SLURM_JOBID starting" tom
	Shutdown requested with JobID $SLURM_JOBID is ready to run.
_EOF_

exit 0