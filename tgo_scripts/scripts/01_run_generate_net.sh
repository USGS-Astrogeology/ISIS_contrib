#!/bin/bash

# This script runs seedgrid to generate a control network and then adds all of
# the frame images to the network.

# Setup directories
mkdir -p Maps
mkdir -p Networks

# Use mosrange to get the ground extents of the images
mosrange fromlist=frame_cubes.lis to=Maps/apriori_equi.map projection=equirectangular precision=4
MINLON=$(getkey from=Maps/apriori_equi.map grpname=Mapping keyword=MinimumLongitude)
MAXLON=$(getkey from=Maps/apriori_equi.map grpname=Mapping keyword=MaximumLongitude)
LONSTEP=$(bc -l <<< "(${MAXLON} - ${MINLON}) / 80")
MINLAT=$(getkey from=Maps/apriori_equi.map grpname=Mapping keyword=MinimumLatitude)
MAXLAT=$(getkey from=Maps/apriori_equi.map grpname=Mapping keyword=MaximumLatitude)
LATSTEP=$(bc -l <<< "(${MAXLAT} - ${MINLAT}) / 80")

# Generate the network
seedgrid target=mars spacing=latlon pointid='id?????' onet=Networks/seed_grid.net \
         minlat=$MINLAT maxlat=$MAXLAT minlon=$MINLON maxlon=$MAXLON \
         latstep=$LATSTEP lonstep=$LONSTEP

# Add all of the full frame cubes to a frame network
cnetadd cnet=Networks/seed_grid.net onet=Networks/seed_grid_frames.net \
        fromlist=frame_cubes.lis addlist=frame_cubes.lis \
        deffile=cnetadd_cal.def retrieval=point

# Remove control points with less than two measures
cnetedit cnet=Networks/seed_grid_frames.net onet=Networks/seed_grid_frames_edited.net
