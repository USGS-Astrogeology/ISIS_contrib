#!/bin/bash

# Script to reproject a list of Rosetta OSIRIS images into the perspective of a given image.
# The ISISROOT variable must be set.
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
#  $4 - The directory where all files will be output
#
# Usage: ros_osiris_reproject_serial basenames.lis perspective_image /path/to/raw/data /working/directory
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#


numFiles=`wc -l < $1`
echo "Processing $numFiles files."
echo ""

if [ -z "$ISISROOT"]; then
  echo "Environment variable ISISROOT must be set before running this script."
  exit
fi

raw_dir=$3
output_dir=$4
ingested_dir=$output_dir"/ingested"
stacked_dir=$output_dir"/stacked_reproj"

mkdir -p $ingested_dir
mkdir -p $stacked_dir


# ingest and spiceinit the reference perspective image
rososiris2isis from=$raw_dir/$2.IMG to=$ingested_dir/$2.cub >& /dev/null
spiceinit from=$ingested_dir/$2.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet >& /dev/null
echo "Reference cube $2.cub now set up."
echo ""

# reproject each image
for basename in `cat $1`; do

  echo "Processing image: $basename"

  ./ros_osiris_reproject_image.sh $basename $ingested_dir/$2.cub $raw_dir $output_dir

done

# mosaic all of the images
./ros_osiris_mosaic $1 $output_dir mosaic.cub

echo ""
echo "---Complete---"
