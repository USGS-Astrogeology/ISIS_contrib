isis3world.pl
============


###############################################################################
#
#_TITLE  isis3world.pl - Create a GIS detached header and/or GIS world file
#                           for ISIS 3 image. ISIS 3 cubes should be exported to
#                           a BSQ format or other format like TIFF or Jpeg.
#                           The ISIS 3 cube will most
#                           likely also need a new extension. This program
#                           does not change the extension for you.
#
# Note this version does not need ISIS 3 installed to run
#
#  Pieces of code used are originally from Dr. Herrick
#
#_ARGS  
#
#_Parm  Output header bit types ( 8 or 16)
#
#_Parm  Output header/world formats - gxp (mhdr), raw( hdr), tfw, gfw, jgw, pgw, cube(hdr), aux
#
#_Parm  Input filename
#
#_USER  Command line entry options [optional parameters]:
#
#   isis3world.pl [-bit=8|16] [-r|-g|-t|-c|-j|-p|-P|-gxp] input.cub
#
# Requirements:
#
#   - images should be level 2 (map projected)
#
# Examples: 
#       1) To generate a tif worldfile 
#
#              isis3world.pl -t input.cub
#
#       2) To generate an 8-bit ISIS cube file using all defaults:
#              isis3world.pl input.bsq
#
#_DESC Convert an ISIS 3 cube to a GIS header and world files.
#
#      Options:
#       1) Input file from 8/16 bit (-bit=8|16)
#             Default: 8 bit
#
#       2) Output Options:
#                (-r) Generate a raw output header and world files
#
#                (-gxp) Generate a raw output header for Socet GXP
#
#                (-e) Generate a ERDAS raw output header and world files
#
#                (-g) Generate gif wold file
#
#                (-t) Generate tif world file
#
#                (-j) Generate jpeg world file
#
#                (-J) Generate jpeg2000 world file
#
#                (-P) Generate png world file
#
#                (-p) Generate a PCI Aux header (w/ georef) file
#
#                (-prj) Generate a ESRI Well Known Text Projection file (useful for ArcMap and GDAL)
#
#                (-o=input.raw,8|16) an override swtich ISIS file to point at raw file instead of an ISIS file.
#
#             Default:
#                (-c) Generate an ISIS output cube header (w/georef) file
#                
#       3) Output GIS header filenames:  input.hdr, input_8b.hdr, input_16b.hdr, input.raw, input.aux
#                      world GIS files:  input.rrw, input.tfw, input.gfw, input.jgw, input.pgw
#
#_FILE Input files utilized 
#
#
#_LIMS  Design limitations
#        - General use
#    
#_CALL  List of calls:
#
#       List of external Perl modules
#          Math::Trig
#
#       List of ISIS programs that are called:
#
#       Unix utility: 
#
#_HIST
#       Jan 07 2005 - Trent Hare - Program rewritten from isis2world.pl
#       Jun 19 2006 - T.H. - fix PCI Aux bug and add png support
#       Feb 14 2007 - T.H. - fix skipbyte error and another PCI Aux bug
#       Sep 16 2007 - T.H. - Added "prj" option to create a ESRI projection file
#                          - Added "-J" for Jpeg2000 *.j2w
#       Sep 17 2007 - T.H. - Added "-o=input.raw,8|16" to override output with raw
#       Oct 25 2007 - T.H. - Added ERDAS raw TILED output
#       Nov 29 2007 - T.H. - Added support for uppercase projections from ISIS3 label
#       Nov 30 2007 - T.H. - Added back in support for PCI Aux to simulate a 2 band
#                            image as a 3 band for anaglyph conversion
#       July 2 2009 - T.H. - Change Standard_Parallel_1 to latitude_of_origin for Polar Stereographic
#       Mar 25 2015 - T.H. - Added GXP mhdr format
#       May 18 2016 - T.H. - added support for multiple extensions
#       Feb 23 2017 - T.H. - Updated Simple Cylindrical to force a sphere since that is what ISIS uses in
#                                                the projection (for either ographic or ocentric).

#FORMAT TILED
#TILE WIDTH 64
#TILE HEIGHT 64

#
#_END
######################################################################
