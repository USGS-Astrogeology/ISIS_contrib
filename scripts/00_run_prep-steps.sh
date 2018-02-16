#!/bin/bash

# This script performs several setup steps required to work with the TGO CaSSIS
# images. Those steps are:
#
# 1. Setup the directories where the ingested cube files will be located
# 2. Ingest the images
# 3. Run spiceinit to get apriori orientation for the images
# 4. Stitch the ingested framelet cubes into full frame cubes
# 5. Generate several lists for future processing
#
# This script requires an input csv file that contains the images to ingest and
# their location. The first entry for each record should be the path to the
# directory containing the image data files and labels. The second entry should
# be the basename of the image data file and label. An example record is below
#
# /CaSSIS_data/MCO/161122_periapsis_orbit09/level1b/ CAS-MCO-2016-11-22T16.05.51.290-BLU-03000-B1

# Setup directories
mkdir -p Lev1

# Ingest images
tgocassis2isis -batchlist=input.lis from=\$1\$2.xml to=Lev1_Framelets/\$2.cub
ls Lev1_Framelets/*cub > framelet_cubes.lis

# Get apriori orientations
spiceinit -batchlist=framelet_cubes.lis from=\$1 ckpredicted=true spkpredicted=true

# Stitch framelets
stitch fromlist=framelet_cubes.lis to=Lev1/CAS-MCO.cub

# Make lists
ls Lev1/*cub > frame_cubes.lis
sed 's/.cub//' frame_cubes.lis | sed 's/Lev1\///' > frame_roots.lis
