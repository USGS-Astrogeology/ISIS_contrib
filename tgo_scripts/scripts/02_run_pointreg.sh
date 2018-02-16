#!/bin/bash

# This script runs pointreg in order to refine the match between images prior
# to bundle adjustment. This script uses two def files to control how pointreg
# runs. Modify reg.def if the first run is rejecting too many measures. The
# second def file, reg_larger_search.def, should be keep a large search radius
# to ensure that there is sufficient control across all filters. 

# Do a first pass with a small pattern and search chip
pointreg fromlist=frame_cubes.lis \
         cnet=Networks/seed_grid_frames_edited.net \
         deffile=reg.def \
         onet=Networks/seed_grid_frames_edited_pntreg.net

# Do another pass with a larger search chip
# This pass will only operate on measures that were not registered by the first
# pass.
pointreg fromlist=frame_cubes.lis \
         cnet=Networks/seed_grid_frames_edited.net \
         deffile=reg_larger_search.def \
         onet=Networks/seed_grid_frames_edited_pntreg.net

# If the control network is not sufficiently tied after this step, then more
# passes and/or changes to the pointreg def files can help to register more
# points. Note that increasing the size of the search area will account for
# greater variance between apriori pointing but at the cost of more computation
# time.
