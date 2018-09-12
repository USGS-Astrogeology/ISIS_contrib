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
#  $2 - Perspective image: The image whose viewing geometry will be used to reproject, no file extension
#
#  $3 - The directory where the raw .IMG and .LBL files from the previous parameters are located
#
#  $4 - The directory where the perspective image is located
#
#  $5 - The directory where all files will be output
#
#  $6 - minimum mask threshold (e.g. 0.0001)
#
# Usage: ros_osiris_reproject_serial basenames.lis perspective_image /path/to/raw/data /path/to/perspective/data /working/directory filter_threshold
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#

input_images=$1
perspective_image=$2
raw_dir=$3
perspective_dir=$4
output_dir=$5
minimum_mask=$6
ingested_dir=$output_dir"/ingested"
stacked_dir=$output_dir"/stacked_reproj"


numFiles=`wc -l < $input_images`
echo "Processing $numFiles files."
echo ""

if [ -z ${ISISROOT+x} ]; then
  echo "Environment variable ISISROOT must be set before running this script."
  exit
fi

mkdir -p $ingested_dir
mkdir -p $stacked_dir


# ingest and spiceinit the reference perspective image
rososiris2isis from=$perspective_dir/$perspective_image.IMG to=$ingested_dir/$perspective_image.cub 
spiceinit from=$ingested_dir/$perspective_image.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet 
echo "Reference cube $perspective_image.cub now set up."
echo ""

# reproject each image
for basename in `cat $input_images`; do
  echo ""
  echo "Processing image: $basename"

  ./ros_osiris_reproject_image.sh $basename $ingested_dir/$perspective_image.cub $raw_dir $output_dir $minimum_mask

done

# mosaic all of the images
echo ./ros_osiris_mosaic.sh $input_images $output_dir mosaic.cub
./ros_osiris_mosaic.sh $input_images $output_dir mosaic.cub

echo ""
echo "---Complete---"
