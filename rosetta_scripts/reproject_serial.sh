#!/bin/bash

# Simple ISIS3 processing pipeline script.
# by Kaj Williams and Jesse Mapel
# Usage: ./reproject_serial.sh fileList.txt    (fileList.txt contains filenames, one per line, with no extensions) 
# Notes:  This script reprojects all files in fileList.txt into the perspecive of N20140806T051914575ID30F22.
#         The result is a cube "stacked.cub".



firstTimeThru=true
workdir="/work/projects/rosetta/hydra_images"  # same as --workdir


for basename in `cat $1`; do

  echo "Processing image: $basename"
  if "$firstTimeThru"; then
     firstTimeThru=false
  fi
done

source /usgs/cpkgs/isis3/isis3mgr_scripts/initIsisCmake.sh isis3nightly

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


# ingest and spiceinit the reference image:
rososiris2isis from=$raw_dir/N20140806T051914575ID30F22.IMG to=$ingested_dir/N20140806T051914575ID30F22.cub >& /dev/null
spiceinit from=$ingested_dir/N20140806T051914575ID30F22.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet >& /dev/null
echo "Reference cube N20140806T051914575ID30F22.cub now set up."
echo ""


for basename in `cat $1`; do

  echo "Processing image: $basename"

  # Ingest the image
  rososiris2isis from=$raw_dir/$basename.IMG to=$ingested_dir/$basename.cub >& /dev/null
  echo "1/8---Ingestion complete."

  # spiceinit the image
  spiceinit from=$ingested_dir/$basename.cub shape=user model=$ISIS3DATA/rosetta/kernels/dsk/ROS_CG_M004_OSPGDLR_U_V1.bds -preference=IsisPreferences_Bullet >& /dev/null
  echo "2/8---Spiceinit complete."

  # Mask the image
  mask minimum=0.0001 from=$ingested_dir/$basename.cub to=$mask_dir/$basename.cub >& /dev/null

  # compute the pixel resolution
  camdev dn=no planetocentriclatitude=no pixelresolution=yes from=$mask_dir/$basename.cub to=$pixres_dir/$basename.cub >& /dev/null
  echo "3/8---Pixel resolution computed."

  # reproject the image data
  cam2cam from=$mask_dir/$basename.cub to=$reproj_dn_dir/$basename.cub match=$ingested_dir/N20140806T051914575ID30F22.cub >& /dev/null
  echo "4/8---Image reprojected."

  # reproject the pixel resolution
  cam2cam from=$pixres_dir/$basename.cub to=$reproj_pixres_dir/$basename.cub match=$ingested_dir/N20140806T051914575ID30F22.cub >& /dev/null
  echo "5/8---Pixel resolution reprojected."

  # adjust the pixel resolution label
  editlab from=$reproj_pixres_dir/$basename.cub grpname=BandBin keyword=CombinedFilterName value=pixel_resolution >& /dev/null
  echo "6/8---Pixel resolution label edited."

  # stack the image data and pixel resolution data
  echo $reproj_dn_dir/$basename.cub > $stacked_dir/$basename.lis
  echo $reproj_pixres_dir/$basename.cub >> $stacked_dir/$basename.lis
  cubeit fromlist=$stacked_dir/$basename.lis to=$stacked_dir/$basename.cub >& /dev/null
  echo "7/8---Image data and pixel resolution data now stacked."

  # mosaic the first image:
  if "$firstTimeThru"; then
    handmos from=$ingested_dir/N20140806T051914575ID30F22.cub mosaic=stacked.cub priority=average create=yes nsamples=2048 nlines=2048 nbands=1 >& /dev/null
    firstTimeThru=false
  fi
  # mosaic the rest:
  handmos from=$stacked_dir/$basename.cub mosaic=stacked.cub priority=average >& /dev/null
  echo "8/8---Mosaic complete."
  echo ""

done
