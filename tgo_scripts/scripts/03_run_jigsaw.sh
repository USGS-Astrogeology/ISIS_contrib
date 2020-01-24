#!/bin/bash

# This script runs jigsaw (bundle adjust) to adjust the pointing information
# based on the control networks.

# Setup directories
mkdir -p Adjusted_Lev1

# Copy the cubes to the new directories
# We are modifying the pointing information attached to the cubes, so keep the
# apriori information on the original cubes and modify copies.
cp Lev1/*.cub Adjusted_Lev1/

# Create a new list
ls Adjusted_Lev1/*.cub > frame_adjusted_cubes.lis

# Bundle the frames
jigsaw fromlist=frame_adjusted_cubes.lis \
       cnet=Networks/seed_grid_frames_edited_pntreg.net \
       onet=Networks/seed_grid_frames_edited_pntreg_jig.net \
       update=yes camera_angles_sigma=1 \
       file_prefix=Networks/seed_grid_frames_edited_pntreg_jig
