#!/bin/bash

# Script to reproject a list of Rosetta OSIRIS images into the perspective of a given image.
# The ISISROOT variable must be set. This uses the USGS Nebula cluster
# for parallel processing
#
# Parameters:
#
#  (Required) l - The list of image basenames to reproject. Each image should be on its own line without
#       file extension or path (ie. just basename). For example, the contents could be as follows:
#                 N20140801T115049599ID30F27
#                 N20140801T132117651ID30F27
#                 N20140801T144423558ID30F27
#
#  (Required) p - Perspective image: The image whose viewing geometry will be used to reproject,
#        This must be a spiceinited ISIS cube.
#
#  i - The directory where the raw .IMG and .LBL files from the previous parameters are located
#
#  o - The directory where all files will be output
#
#  m - minimum mask threshold (e.g. 0.0001)
#
# Usage: ros_osiris_reproject_parallel.sh -l basenames.lis -p /path/to/perspective/data/perspective_image.cub -i /path/to/raw/data -o /output/directory -m filter_threshold
#
# Example: ./ros_osiris_reproject_parallel.sh -l batchList_short.txt -p perspective/path/N20140816T165914570ID30F22.cub -i ./images -o ./output -m 0.0001
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#

echo ""
cwd=$PWD
echo "cwd: $cwd"
echo ""

got_input_list=0
got_perspective_image=0

while getopts 'l:p:i:d:o:m:' OPTION; do
  case "$OPTION" in
    l)
      input_images="$OPTARG"
      echo "File containing lists of images to reproject: $input_images"
      got_input_list=1
      ;;
    p)
      perspective_image="$OPTARG"
      echo "Perspective image: $perspective_image"
      got_perspective_image=1
      ;;
    i)
      raw_dir=$(readlink -f "$OPTARG")
      echo "Directory where raw images are located: $raw_dir"
      ;;
    o)
      output_dir=$(readlink -f "$OPTARG") #"$cwd/$OPTARG"
      echo "Output directory: $output_dir"
      ;;
    m)
      minimum_mask="$OPTARG"
      echo "Minimum mask: $minimum_mask"
      ;;
    ?)
      echo "Invalid args: $OPTARG" >&2
      echo "script usage: $(basename $0) [-l filelist] [-p perspective_image] [-i images_dir] [-o output_dir] [-m minimum_mask]" >&2
      exit 1
      ;;
  esac
done

if [ $got_input_list -eq 0 ] || [ $got_perspective_image -eq 0 ]; then
  echo ""
  echo "Required arguments missing: you need to supply both an input file list and a perspective image name."
  exit 2
fi

ingested_dir=$output_dir"/ingested"
stacked_dir=$output_dir"/stacked_reproj"
log_dir=$output_dir"/LOGS"
echo "Ingested directory: $ingested_dir"
echo "Stacked image directory: $stacked_dir"
echo "Log directory: $log_dir"

numFiles=`wc -l < $input_images`
echo ""
echo "Processing $numFiles files."
echo ""


if [ -z ${ISISROOT+x} ]; then
  echo "Environment variable ISISROOT must be set before running this script."
  exit
fi

mkdir -p $ingested_dir
mkdir -p $stacked_dir
mkdir -p $log_dir
cp IsisPreferences_Bullet $output_dir

# we need to create a big list of all the slurm jobs we're making for later
slurm_job_names=""

# reproject each image
for basename in `cat $cwd/$input_images`; do
  #$basename=$cwd/input/$basename
  echo "Reprojecting: $basename"
  job_id=$(sbatch --partition=shortall --time=01:00:00 --mem=1000 \
  --job-name=ROS_Projection --output=LOGS/$basename.log --workdir=$output_dir \
  ros_osiris_reproject_image.sh $basename $perspective_image $raw_dir $output_dir $minimum_mask)

# parameter substitution magic, job_id is "Submitted batch job ######" this
# extracts the final word
  slurm_job_names="$slurm_job_names:${job_id##* }"
done

# mosaic all of the images
# here we use the big list of slurm jobs to make sure the mosaic happens
# after everything is reprojected
echo "Mosaicing images"
sbatch --partition=longall --wait --time=01:00:00 --mem=1000 \
--job-name=ROS_Mosaic --output=LOGS/mosaic.log \
--workdir=$output_dir  --dependency=afterok$slurm_job_names \
ros_osiris_mosaic.sh $cwd/$input_images $output_dir mosaic.cub

echo ""
echo "---Complete---"
