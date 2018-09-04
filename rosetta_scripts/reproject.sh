#!/bin/bash

# Parameters for SLURM scheduler
#SBATCH --partition=shortall                        # partition to submit to
                                                    # Nebula defaults to the shortall partition
                                                    # for jobs < 1 hour

#SBATCH --time=01:00:00                             # time needed to complete task

#SBATCH --mem=1000                                  # memory needed per task in MB

#SBATCH --job-name=ROS_Projection                    # job name seen via squeue

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

source /usgs/cpkgs/isis3/isis3mgr_scripts/initIsisCmake.sh isis3nightly

# Execute Processing Command(s)
# use array index value to determine which input list gets passed to processing script
basename=`cat $1 |head -n ${taskid} |tail -1`
echo "Processing image: $basename"

raw_dir="/work/projects/rosetta/psa_osiris_data/psa.esac.esa.int/pub/mirror/INTERNATIONAL-ROSETTA-MISSION/OSINAC/RO-C-OSINAC-3-PRL-67PCHURYUMOV-M06-V2.0/DATA/2014_08"
ingested_dir="ingested"
mask_dir="masked"
pixres_dir="resolution"
reproj_dn_dir="reproj"
reproj_pixres_dir="reproj_pixres"
stacked_dir="stacked_reproj"

mkdir -p $ingested_dir
mkdir -p $mask_dir
mkdir -p $pixres_dir
mkdir -p $reproj_dn_dir
mkdir -p $reproj_pixres_dir
mkdir -p $stacked_dir


# Ingest the image
rososiris2isis from=$raw_dir/$basename.IMG to=$ingested_dir/$basename.cub

# spiceinit the image
spiceinit from=$ingested_dir/$basename.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet

# Mask the image
mask minimum=0.00001 from=$ingested_dir/$basename.cub to=$mask_dir/$basename.cub

# compute the pixel resolution
camdev dn=no planetocentriclatitude=no pixelresolution=yes from=$mask_dir/$basename.cub to=$pixres_dir/$basename.cub

# reproject the image data
cam2cam from=$mask_dir/$basename.cub to=$reproj_dn_dir/$basename.cub match=N20140806T051914575ID30F22.cub

# reproject the pixel resolution
cam2cam from=$pixres_dir/$basename.cub to=$reproj_pixres_dir/$basename.cub match=N20140806T051914575ID30F22.cub

# adjust the pixel resolution label
editlab from=$reproj_pixres_dir/$basename.cub grpname=BandBin keyword=CombinedFilterName value=pixel_resolution

# stack the image data and pixel resolution data
echo $reproj_dn_dir/$basename.cub > $stacked_dir/$basename.lis
echo $reproj_pixres_dir/$basename.cub >> $stacked_dir/$basename.lis
cubeit fromlist=$stacked_dir/$basename.lis to=$stacked_dir/$basename.cub
