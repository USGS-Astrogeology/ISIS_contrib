#!/bin/bash

# Script to reproject a list of Rosetta OSIRIS images into the perspective of a given image.
# The ISISROOT variable must be set. This uses the USGS Nebula cluster
# for parallel processing
#
# Parameters:
#
#  $1 - The list of image basenames to reproject. Each image should be on its own line without
#       file extension or path (ie. just basename). For example, the contents could be as follows:
#                 N20140801T115049599ID30F27
#                 N20140801T132117651ID30F27
#                 N20140801T144423558ID30F27
#
#  $2 - The image whose viewing geometry will be used to reproject, no file extension
#
#  $3 - The directory where the raw .IMG and .LBL files from the previous parameters are located
#
#  $4 - The directory where the perspective image is located
#
#  $5 - The directory where all files will be output
#
# Usage: ros_osiris_reproject_parallel basenames.lis perspective_image /path/to/raw/data /path/to/perspective/data /working/directory
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#


numFiles=`wc -l < $1`
echo "Processing $numFiles files."
echo ""

if [ -z "$ISISROOT" ]; then
  echo "Environment variable ISISROOT must be set before running this script."
  exit
fi

input_images=$1
perspective_image=$2
raw_dir=$3
perspective_dir=$4
output_dir=$5
ingested_dir=$output_dir"/ingested"
stacked_dir=$output_dir"/stacked_reproj"
log_dir=$output_dir"/LOGS"

mkdir -p $ingested_dir
mkdir -p $stacked_dir
mkdir -p $log_dir

# ingest and spiceinit the reference perspective image
rososiris2isis from=$perspective_dir/$perspective_image.IMG to=$ingested_dir/$perspective_image.cub >& /dev/null
spiceinit from=$ingested_dir/$perspective_image.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet >& /dev/null
echo "Reference cube $perspective_image.cub now set up."
echo ""

# we need to create a big list of all the slurm jobs we're making for later
slurm_job_names=""

# reproject each image
for basename in `cat $input_images`; do
  job_id=$(sbatch --partition=shortall --time=01:00:00 --mem=1000 \
  --job-name=ROS_Projection --output=LOGS/$basename.log --workdir=$output_dir \
  ros_osiris_reproject_image.sh $basename $ingested_dir/$perspective_image.cub $raw_dir $output_dir)

# parameter substitution magic, job_id is "Submitted batch job ######" this
# extracts the final word
  slurm_job_names="$slurm_job_names:${job_id##* }"
done

# mosaic all of the images
# here we use the big list of slurm jobs to make sure the mosaic happens
# after everything is reprojected
sbatch --partition=longall --time=01:00:00 --mem=1000 \
--job-name=ROS_Mosaic --output=LOGS/mosaic.log \
--workdir=$output_dir  --dependency=afterok$slurm_job_names \
ros_osiris_mosaic.sh $input_images $output_dir mosaic.cub

echo ""
echo "---Complete---"
