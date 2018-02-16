#!/bin/bash

# This script mosaics map projected frame images into single filter mosaics and
# a full color mosaic

# Setup directories
mkdir -p Mosaics

# Determine the mosaic extents
MINLON=$(getkey from=Maps/equi_frame_adjusted.map grpname=Mapping keyword=MinimumLongitude)
MAXLON=$(getkey from=Maps/equi_frame_adjusted.map grpname=Mapping keyword=MaximumLongitude)
MINLAT=$(getkey from=Maps/equi_frame_adjusted.map grpname=Mapping keyword=MinimumLatitude)
MAXLAT=$(getkey from=Maps/equi_frame_adjusted.map grpname=Mapping keyword=MaximumLatitude)

# Mosaic the individual colors
while read FILTERLIST
do
  FILTERNAME=$(basename ${FILTERLIST} _eq.lis)
  automos fromlist=${FILTERLIST} mosaic=Mosaics/${FILTERNAME}_eq.cub grange=user \
          minlon=${MINLON} maxlon=${MAXLON} minlat=${MINLAT} maxlat=${MAXLAT}
done < filter_lists.lis

# Create a list of the individual mosaics
ls Mosaics/[A-Z][A-Z][A-Z]_eq.cub > filter_mosaics.lis

# Create the color mosaic
cubeit fromlist=filter_mosaics.lis to=Mosaics/color_eq.cub
