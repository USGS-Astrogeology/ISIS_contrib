#!/bin/bash

# Parameters for SLURM scheduler
#SBATCH --partition=shortall                        # partition to submit to
                                                    # Nebula defaults to the shortall partition
                                                    # for jobs < 1 hour

#SBATCH --time=01:00:00                             # time needed to complete task

#SBATCH --mem=1000                                  # memory needed per task in MB

#SBATCH --job-name=ROS_Ingestion                    # job name seen via squeue

#SBATCH --output=LOGS/LOG_%A-%a_%N.out              # standard output/error output file
                                                    # %A is job id
                                                    # %a is array index
                                                    # %N is the node used

#SBATCH --workdir=/work/projects/rosetta/hydra_images  # directory where work will be performed

workdir="/work/projects/rosetta/hydra_images"  # same as --workdir
submitdir=$SLURM_SUBMIT_DIR      # directory from where job is submitted
node=$SLURMD_NODENAME            # name of node job is executed on
jobid=$SLURM_ARRAY_JOB_ID        # job array's master job ID number
taskid=$SLURM_ARRAY_TASK_ID      # job array task id number
startdate=`date +"%Y-%m-%dT%T"`  # when job was submitted

# set HOST to match that of node job is running on
#  this is so ISIS print.prt records proper HOSTNAME (it uses HOST, which is still set to submitting HOST under bash)
export HOST=$SLURMD_NODENAME

# Execute Processing Command(s)
# use array index value to determine which input list gets passed to processing script
basename=`cat $1 |head -n ${taskid} |tail -1`
echo "Processing image: $basename"

todir="ingested"
inputdir="/work/projects/rosetta/psa_osiris_data/psa.esac.esa.int/pub/mirror/INTERNATIONAL-ROSETTA-MISSION/OSINAC/RO-C-OSINAC-3-PRL-67PCHURYUMOV-M06-V2.0/DATA/2014_08"

# Ingest the image
rososiris2isis from=$inputdir/$basename.IMG to=$todir/$basename.cub

# spiceinit the image
spiceinit from=$todir/$basename.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet
