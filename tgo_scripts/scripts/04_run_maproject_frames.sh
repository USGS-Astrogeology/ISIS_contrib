#!/bin/bash

# This script map projects the adjusted frames

# Setup directories
mkdir -p Unstitched
mkdir -p Lev2

# Generate map files for the adjusted images
mosrange fromlist=frame_adjusted_cubes.lis to=Maps/equi_frame_adjusted.map projection=equirectangular precision=4

# Unstitch and project the frame images
while read FRAME
do
  FRAMEBASE=$(basename ${FRAME} .cub)
  unstitch from=${FRAME} to=Unstitched/${FRAMEBASE}.cub
  FILTERS=$(getkey from=${FRAME} grpname=Stitch keyword=OriginalFilters)
  IFS=', ' read -r -a FILTERSARRAY <<< "${FILTERS}"
  for FILTER in "${FILTERSARRAY[@]}"
  do
    cam2map from=Unstitched/${FRAMEBASE}_${FILTER}.cub to=Lev2/${FRAMEBASE}_${FILTER}_eq.cub \
            map=Maps/equi_frame_adjusted.map pixres=map
  done
done < frame_adjusted_cubes.lis

# Create filter image lists for mosaicing
for FILTER in "${FILTERSARRAY[@]}"
do
  ls Lev2/*_${FILTER}_eq.cub > ${FILTER}_eq.lis
done
ls *eq.lis > filter_lists.lis
