#!/bin/bash

#SBATCH --cpus-per-task 8
#SBATCH --nice=1000
#SBATCH --exclusive
#SBATCH --mail-type=ALL
#SBATCH --job-name="shutdown"
#SBATCH --output="/var/log/slurmShutdown/log.job.txt"
#SBATCH --open-mode=append

logdir="/var/log/slurmShutdown"

# catch interruptions
clean_up() {
	cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job $SLURM_JOBID CANCELLED" tom
	Shutdown requested with JobID $SLURM_JOBID was cancelled at $(date).
_EOF_
	rm "$logdir"/jobRun.flag
	touch "$logdir"/jobFail.flag
	exit 1
}
trap clean_up SIGHUP SIGINT SIGTERM

# touch jobRun
touch "$logdir"/jobRun.flag

# wait and check queue in case new jobs were added
sleep 30

# if jobs were added
if [[ $(squeue -a | wc -l) -gt 2 ]]; then
	# rm jobRun, create jobFail and exit
	rm "$logdir"/jobRun.flag
	touch "$logdir"/jobFail.flag
	cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job $SLURM_JOBID did not run" tom
	Shutdown requested with JobID $SLURM_JOBID did not run because other jobs were submitted.

	$(squeue -a)
_EOF_
	exit 1
fi

# otherwise, queue is empty

# create jobFinished flag
touch "$logdir"/jobFinished.flag

# email notification
cat <<- _EOF_ | mail -s "[Tom@SLURM] Shutdown job $SLURM_JOBID starting" tom
	Shutdown requested with JobID $SLURM_JOBID starting at $(date) plus six minutes.
_EOF_

# wait 2m for wrapper to exit
sleep 2m

# wait 6 minutes and shut down
shutdown -h +6