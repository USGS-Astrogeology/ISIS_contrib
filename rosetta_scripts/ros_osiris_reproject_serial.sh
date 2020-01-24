#!/bin/bash

# Script to reproject a list of Rosetta OSIRIS images into the perspective of a given image.
# The ISISROOT variable must be set.
#
# Parameters:
#
#  (Required) l - The list of image basenames to reproject. Each image should be on its own line without
#       file extension or path (ie. just basename). For example, the contents could be as follows:
#                 N20140801T115049599ID30F27
#                 N20140801T132117651ID30F27
#                 N20140801T144423558ID30F27
#
#  (Required) p - Perspective image: The image whose viewing geometry will be used to reproject, no file extension
#
#  i - The directory where the raw .IMG and .LBL files from the previous parameters are located
#
#  d - The directory where the perspective image is located
#
#  o - The directory where all files will be output
#
#  m - minimum mask threshold (e.g. 0.0001)
#
# Usage: ros_osiris_reproject_serial -l basenames.lis -p perspective_image -i /path/to/raw/data -d /path/to/perspective/data -o /working/directory -m filter_threshold
#
# Example: ./ros_osiris_reproject_serial.sh -l batchList_short.txt -p N20140816T165914570ID30F22 -i ./images -d ./perspectives -o ./output -m 0.0001
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#

got_input_list=0
got_perspective_image=0

image_count=0

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
      raw_dir="$OPTARG"
      echo "Directory where raw images are located: $raw_dir"
      ;;
    d)
      perspective_dir="$OPTARG"
      echo "Perspective directory: $perspective_dir"
      ;;
    o)
      output_dir="$OPTARG"
      echo "Output directory: $output_dir"
      ;;
    m)
      minimum_mask="$OPTARG"
      echo "Minimum mask: $minimum_mask"
      ;;
    ?)
      #echo "Invalid args: $OPTARG" >&2
      echo "script usage: $(basename $0) [-l filelist] [-p perspective_image] [-i images_dir] [-d perspective_dir] [-o output_dir] [-m minimum_mask]" >&2
      exit 1
      ;;
  esac
done

if [ $got_input_list -eq 0 ] || [ $got_perspective_image -eq 0 ]; then
  echo "Required arguments missing: you need to supply both an input file list and a perspective image name."
  exit 2
fi


ingested_dir=$output_dir"/ingested"
stacked_dir=$output_dir"/stacked_reproj"


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


# ingest and spiceinit the reference perspective image
rososiris2isis from=$perspective_dir/$perspective_image.IMG to=$ingested_dir/$perspective_image.cub 
spiceinit from=$ingested_dir/$perspective_image.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet 
echo "Reference cube $perspective_image.cub now set up."
echo ""

# reproject each image
for basename in `cat $input_images`; do
  image_count=`expr $image_count + 1`
  echo ""
  echo ""
  echo "Processing image $image_count/$numFiles: $basename"

  ./ros_osiris_reproject_image.sh $basename $ingested_dir/$perspective_image.cub $raw_dir $output_dir $minimum_mask

done

# mosaic all of the images
echo ./ros_osiris_mosaic.sh $input_images $output_dir mosaic.cub
./ros_osiris_mosaic.sh $input_images $output_dir mosaic.cub

echo ""
echo "---Complete---"
