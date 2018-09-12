#!/bin/bash

# Script to mosaic a set of Rosetta OSIRIS images after they have been reprojected.
# The ISISROOT variable must be set.
#
# Parameters:
#
#  $1 - The list of image basenames to mosaic. Each image should be on its own line without
#       file extension or path (ie. just basename). For example, the contents could be as follows:
#                 N20140801T115049599ID30F27
#                 N20140801T132117651ID30F27
#                 N20140801T144423558ID30F27
#
#  $2 - The directory where all files will be output
#
#  $3 - The output mosaic filename. This will be created in the output directory
#
# Usage: ros_osiris_mosaic.sh basenames.lis /working/directory mosaic.cub
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#

firstTimeThru=true

output_dir=$2
output_mosaic=$output_dir/$3

stacked_dir=$output_dir"/stacked_reproj"

if [ -z ${ISISROOT+x} ]; then
  echo "Environment variable ISISROOT must be set before running this script."
  exit
fi

for basename in `cat $1`; do
  echo "Mosaicing image: $basename"

  # For the first image we have to make a different handmos call to create the cube
  if "$firstTimeThru"; then
    echo "  Creating new mosaic"
    handmos from=$stacked_dir/$basename.cub mosaic=$output_mosaic priority=average create=yes nsamples=2048 nlines=2048 nbands=1 >& /dev/null
    firstTimeThru=false
  else
    echo "  Averaging into existing mosaic"
    handmos from=$stacked_dir/$basename.cub mosaic=$output_mosaic priority=average >& /dev/null
  fi
done
