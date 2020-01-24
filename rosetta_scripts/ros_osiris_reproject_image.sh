#!/bin/bash

# Script to reproject a single of Rosetta OSIRIS images into the perspective of another image.
# The ISISROOT variable must be set.
#
# Parameters:
#
#  $1 - The basename of the image to reproject without a path or file extension
#
#  $2 - Perspective image: The image whose viewing geometry will be used to reproject
#
#  $3 - The directory where the raw .IMG and .LBL file for the input image are located
#
#  $4 - The directory where all files will be output
#
#  $5 - Minimum mask threshold (e.g. 0.0001)
#
# Usage: ros_osiris_reproject_image basename perspective_image.cub /path/to/raw/data/ /working/directory filter_threshold
#
# Authors: Jesse Mapel, Makayla Shepherd, and Kaj Williams
#

if [ -z ${ISISROOT+x} ]; then
  echo "Environment variable ISISROOT must be set before running this script."
  exit
fi

cwd=$PWD
basename=$1
raw_dir=$3
output_dir=$4
minimum_mask=$5
ingested_dir=$output_dir"/ingested"
mask_dir=$output_dir"/masked"
pixres_dir=$output_dir"/resolution"
reproj_dn_dir=$output_dir"/reproj"
reproj_pixres_dir=$output_dir"/reproj_pixres"
stacked_dir=$output_dir"/stacked_reproj"

mkdir -p $ingested_dir
mkdir -p $mask_dir
mkdir -p $pixres_dir
mkdir -p $reproj_dn_dir
mkdir -p $reproj_pixres_dir
mkdir -p $stacked_dir


# Ingest the image
rososiris2isis from=$raw_dir/$basename.IMG to=$ingested_dir/$basename.cub
echo "1/7---Ingestion complete."

# spiceinit the image
spiceinit from=$ingested_dir/$basename.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet
echo "2/7---Spiceinit complete."

# Mask the image
mask minimum=$minimum_mask from=$ingested_dir/$basename.cub to=$mask_dir/$basename.cub

# compute the pixel resolution
camdev dn=no planetocentriclatitude=no pixelresolution=yes from=$mask_dir/$basename.cub to=$pixres_dir/$basename.cub
echo "3/7---Pixel resolution computed."

# reproject the image data
cam2cam from=$mask_dir/$basename.cub to=$reproj_dn_dir/$basename.cub match=$2
echo "4/7---Image reprojected."

# reproject the pixel resolution
cam2cam from=$pixres_dir/$basename.cub to=$reproj_pixres_dir/$basename.cub match=$2
echo "5/7---Pixel resolution reprojected."

# adjust the pixel resolution label
editlab from=$reproj_pixres_dir/$basename.cub grpname=BandBin keyword=CombinedFilterName value=pixel_resolution
echo "6/7---Pixel resolution label edited."

# stack the image data and pixel resolution data
echo $reproj_dn_dir/$basename.cub > $stacked_dir/$basename.lis
echo $reproj_pixres_dir/$basename.cub >> $stacked_dir/$basename.lis
cubeit fromlist=$stacked_dir/$basename.lis to=$stacked_dir/$basename.cub
echo "7/7---Image data and pixel resolution data now stacked."
