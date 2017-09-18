#!/usr/bin/env python3

#/******************************************************************************
# * $Id$
# *
# * Name:     isis3_lbl_to_pds3_lbl.py
# * Purpose:  Translate a detached ISIS3 label associated with a map-projected
# *           image product into a PDS3-compliant label file. 
# * Author:   David P. Mayer, dpmayer@usgs.gov
# *
# * License: Public Domain
# *
# ******************************************************************************


import sys
import re
import fileinput
import pvl
from pvl._collections import Units as PUnits

inputlbl = sys.argv[1]
print(inputlbl)
isis3lbl = pvl.load(inputlbl)

# ## Debug only ##
# # Load the ISIS3 input from a file. Can be either detached label, or a cube with attached label
# # isis3lbl = pvl.load('Mercury_MESSENGER_mosaic_global_250m_2013.lbl')
# # isis3lbl = pvl.load('Lunar_Kaguya_MIMap_MineralDeconv_AbundanceSMFe_50N50S.lbl')
# ################

# # TODO: Check that input contains some minimum required set of keywords before translating

# Some keyword value pairs that should always appear at the top of the PDS3 label
# The value of LABEL_REVISION_NOTE should be modified to suit the user's needs
pds3toplevel = """PDS_VERSION_ID = PDS3
DD_VERSION_ID = PDSCAT1R100
LABEL_REVISION_NOTE = \"2017-05-01, David P. Mayer (USGS), initial PDS3 label pointing to GeoTIFF;\"
RECORD_TYPE = FIXED_LENGTH
"""

# Initialize the PDS3 label in memory using the string pds3toplevel
pds3label = pvl.loads(pds3toplevel)

## Check for some optional data description keywords in the Archive group of ISIS3 label
# This is a bit backwards because the ISIS3 Archive group itself typically contains
#  PDS-specific information
try:
    isis3lbl['IsisCube']['Archive']
except KeyError:
    targetname = None
    print("No Archive Group in ISIS3 Label")
else:
    try:
        isis3lbl['IsisCube']['Archive']['DataSetId']
    except KeyError:
        print("No DataSetId in ISIS3 Label")
    else:
        pds3label.append('DATA_SET_ID', (isis3lbl['IsisCube']['Archive']['DataSetId']))

    try:
        isis3lbl['IsisCube']['Archive']['ProducerId']
    except KeyError:
        print("No ProducerId in ISIS3 Label")
    else:
        pds3label.append('PRODUCER_ID', (isis3lbl['IsisCube']['Archive']['ProducerId'].upper()))

    try:
        isis3lbl['IsisCube']['Archive']['ProducerFullName']
    except KeyError:
        print("No ProducerFullName in ISIS3 Label")
    else:
        pds3label.append('PRODUCER_FULL_NAME', isis3lbl['IsisCube']['Archive']['ProducerFullName'].upper())

    try:
        isis3lbl['IsisCube']['Archive']['ProducerInstitutionName']
    except KeyError:
        print("No ProducerInstitutionName in ISIS3 Label")
    else:
        pds3label.append('PRODUCER_INSTITUTION_NAME', isis3lbl['IsisCube']['Archive']['ProducerInstitutionName'].upper())

    try:
        isis3lbl['IsisCube']['Archive']['ProductId']
    except KeyError:
        print("No ProductId in ISIS3 Label")
    else:
        pds3label.append('PRODUCT_ID', (isis3lbl['IsisCube']['Archive']['ProductId']))
    
    try:
        isis3lbl['IsisCube']['Archive']['InstrumentHostName']
    except KeyError:
        print("No InstrumentHostName in ISIS3 Label")
    else:
        pds3label.append('INSTRUMENT_HOST_NAME', isis3lbl['IsisCube']['Archive']['InstrumentHostName'].upper())

    try:
        isis3lbl['IsisCube']['Archive']['InstrumentName']
    except KeyError:
        print("No InstrumentName in ISIS3 Label")
    else:
        pds3label.append('INSTRUMENT_NAME', isis3lbl['IsisCube']['Archive']['InstrumentName'].upper())
        
    try:
        isis3lbl['IsisCube']['Archive']['InstrumentId']
    except KeyError:
        print("No InstrumentId in ISIS3 Label")
    else:
        pds3label.append('INSTRUMENT_ID', isis3lbl['IsisCube']['Archive']['InstrumentId'].upper())


## Determine the offset and scaling_factor based on their ISIS3 label analogs: base and multiplier
try:
    isis3lbl['IsisCube']['Core']['Pixels']['Base']
    isis3lbl['IsisCube']['Core']['Pixels']['Multiplier']
except KeyError:
    # If Base or Multiplier are not found, set offset and scalingfactor to sensible defaults
    offset = 0.0
    scalingfactor = 1.0
else:
    offset = isis3lbl['IsisCube']['Core']['Pixels']['Base']
    scalingfactor = isis3lbl['IsisCube']['Core']['Pixels']['Multiplier']

# Determine the size on disk of each pixel using ISIS3's terms
#  UnsignedByte = 1 byte integer
#  SignedWord = 2 byte signed integer
#  Real = 4 byte IEEE Floating Point
pixeltype = isis3lbl['IsisCube']['Core']['Pixels']['Type']
byteorder = isis3lbl['IsisCube']['Core']['Pixels']['ByteOrder'].upper()
if pixeltype == "UnsignedByte":
    bytetype = 1
    samplebits = 8
    sampletype = (byteorder + "_UNSIGNED_INTEGER")
elif pixeltype == "SignedWord":
    bytetype = 2
    samplebits = 16
    sampletype = (byteorder + "_INTEGER")
elif pixeltype == "Real":
    bytetype = 4
    samplebits = 32
    sampletype = "IEEE_REAL"
# TargetName
# This could also exist as the "Target" keyword in the Archive group if the group exists,
#  but seeing as this script is being developed for map-projected products,
#  we'll look for the target name in the Mapping group, because it's almost certainly there
try:
    isis3lbl['IsisCube']['Mapping']['TargetName']
except KeyError:
    targetname = None
    print("No Target in ISIS3 Label")
else:
    targetname = (isis3lbl['IsisCube']['Mapping']['TargetName']).upper()

recordbytes = (isis3lbl['IsisCube']['Core']['Dimensions']['Samples']*bytetype)
pds3label.append('RECORD_BYTES', recordbytes)

# Append the target name to the PDS3 label
if targetname is not None:
    pds3label.append('TARGET_NAME', targetname)


try:
    isis3lbl['IsisCube']['Core']['Format']
except KeyError:
    # Assume band sequential if this keyword is missing
    bandstoragetype = "BAND_SEQUENTIAL"
else:
    if (isis3lbl['IsisCube']['Core']['Format']) == "BandSequential":
        bandstoragetype = "BAND_SEQUENTIAL"
    else:
        sys.exit("Band storage type unsupported by PDS3")

# NOTE: The PVL library does not currently support writing the values of complex pointers without wrapping them in single quotes.
# This is not a valid format according to the PDS3 standard and it causes other software, such as GDAL to misinterpret the value
# See end of this script for the hack we use to get around this
image = '("'+ isis3lbl['IsisCube']['Core']['^Core'] + '", ' + str(isis3lbl['IsisCube']['Core']['StartByte']) + ' <BYTES>)'
pds3label.append('^IMAGE', image)

# Append the IMAGE object and its contents
pds3label.append('IMAGE', pvl.PVLModule({
    'LINES': isis3lbl['IsisCube']['Core']['Dimensions']['Lines'],
    'LINE_SAMPLES': isis3lbl['IsisCube']['Core']['Dimensions']['Samples'],
    'SAMPLE_BITS': samplebits,
    'SAMPLE_TYPE': sampletype,
    'BANDS' : isis3lbl['IsisCube']['Core']['Dimensions']['Bands'],
    'BAND_STORAGE_TYPE' : bandstoragetype,
    'SCALING_FACTOR' : scalingfactor,
    'OFFSET' : offset}))


# Map Projection Information
#  Extract the number part from the PixelResolution tag
pixres = isis3lbl['IsisCube']['Mapping']['PixelResolution']
if isinstance(pixres, pvl._collections.Units):
    mapscale = pixres.value
elif isinstance(pixres, (int, float)):
    mapscale = pixres

scale = isis3lbl['IsisCube']['Mapping']['Scale']
if isinstance(scale, pvl._collections.Units):
    # Make sure the units are upper case
    mapresolution = PUnits(scale.value, scale.units.upper())
elif isinstance(scale, (int, float)):
    mapresolution = PUnits(scale, 'PIXELS/DEGREE')

longdir = (isis3lbl['IsisCube']['Mapping']['LongitudeDirection'])
positivelongdir = longdir.replace("Positive", "").upper()

if positivelongdir == "EAST":
    easternmostlong = isis3lbl['IsisCube']['Mapping']['MaximumLongitude']
    westernmostlong = isis3lbl['IsisCube']['Mapping']['MinimumLongitude']
    mapscale_x = mapscale
    mapscale_y = (-1 * mapscale)
elif positivelongdir == "WEST":
    easternmostlong = isis3lbl['IsisCube']['Mapping']['MinimumLongitude']
    westernmostlong = isis3lbl['IsisCube']['Mapping']['MaximumLongitude']
    mapscale_x = (-1 * mapscale)
    mapscale_y = mapscale_x

maximumlatitude = isis3lbl['IsisCube']['Mapping']['MaximumLatitude']
minimumlatitude = isis3lbl['IsisCube']['Mapping']['MinimumLatitude']
centerlongitude = isis3lbl['IsisCube']['Mapping']['CenterLongitude']
# Center Latitude is optional for some map projections, so we account for the possibility that it doesn't exist in the input
try:
    isis3lbl['IsisCube']['Mapping']['CenterLatitude']
except KeyError:
    centerlatitude = """N/A"""
else:
    centerlatitude = isis3lbl['IsisCube']['Mapping']['CenterLatitude']


# Set units of various latitudes/longitudes found in the ISIS3 label to 'DEGREES' if units are not already specified
if isinstance(easternmostlong, pvl._collections.Units) == False:
    easternmostlong = PUnits(easternmostlong, 'DEGREES')
if isinstance(westernmostlong, pvl._collections.Units) == False:
    westernmostlong = PUnits(westernmostlong, 'DEGREES')
if isinstance(maximumlatitude, pvl._collections.Units) == False:
    maximumlatitude = PUnits(maximumlatitude, 'DEGREES')
if isinstance(minimumlatitude, pvl._collections.Units) == False:
    minimumlatitude = PUnits(minimumlatitude, 'DEGREES')
if isinstance(centerlatitude, pvl._collections.Units) == False:
    centerlatitude = PUnits(centerlatitude, 'DEGREES')
if isinstance(centerlongitude, pvl._collections.Units) == False:
    centerlongitude = PUnits(centerlongitude, 'DEGREES')

# Calculate the projection offset using the upper left X and Y map coordinates
# Assumes all projected units are in meters
ULY = isis3lbl['IsisCube']['Mapping']['UpperLeftCornerY']
ULX = isis3lbl['IsisCube']['Mapping']['UpperLeftCornerX']

if isinstance(ULX, pvl._collections.Units):
    sampleprojectionoffset = PUnits((-0.5 + (-1 * ULX.value / mapscale_x)), 'PIXELS')
elif isinstance(ULX, (int, float)):
    sampleprojectionoffset = PUnits((-0.5 + (-1 * ULX / mapscale_x)), 'PIXELS')
else:
    print("UpperLeftCornerX and UpperLeftCornerY are not numbers")
    print(ULX)
    print(ULY)

if isinstance(ULY, pvl._collections.Units):
    lineprojectionoffset = PUnits(((-1 * ULY.value / mapscale_y) - 0.5), 'PIXELS')
elif isinstance(ULY, (int, float)):
    lineprojectionoffset = PUnits(((-1 * ULY / mapscale_y) - 0.5), 'PIXELS')
else:
    print("UpperLeftCornerX and UpperLeftCornerY are not numbers")
    print(ULX)
    print(ULY)

## Dealing with some known map projection name inconsistencies between ISIS3 and PDS3 Standard
# Test to identify and correct known issue where "Simple_Cylindrical"
#  sometimes appears as "SimpleCylindrical" in ISIS3 labels.
# The latter is not valid in PDS3 and will cause GDAL to report projection info incorrectly.
# There is a similar issue with "PolarStereographic" vs. "Polar_stereographic"
if (isis3lbl['IsisCube']['Mapping']['ProjectionName']).upper() == "SIMPLECYLINDRICAL":
    # print(isis3lbl['IsisCube']['Mapping']['ProjectionName'])
    mapprojectiontype = "SIMPLE_CYLINDRICAL"
    # print(mapprojectiontype)
elif (isis3lbl['IsisCube']['Mapping']['ProjectionName']).upper() == "POLARSTEREOGRAPHIC":
    mapprojectiontype = "POLAR_STEREOGRAPHIC"
else:
    mapprojectiontype = (isis3lbl['IsisCube']['Mapping']['ProjectionName']).upper()
    
# Attempt to determine units on planetary radii as reported in ISIS3 label
#  and convert to kilometers
a_axis = isis3lbl['IsisCube']['Mapping']['EquatorialRadius']
c_axis = isis3lbl['IsisCube']['Mapping']['PolarRadius']
if isinstance(a_axis, pvl._collections.Units):
    # do some tests to guess units
    if a_axis.units.upper() == ("METERS" or "M"):
        a_axis = (a_axis.value / 1000)
    elif a_axis.units.upper() == ("KILOMETERS" or "KM"):
        a_axis = a_axis.value
    else:
       print("Unsupported units " + a_axis.units)
else:
    # Guess that the units are meters and convert to kilometers
    print("EquatorialRadius has no units attribute. Guessing meters...")
    a_axis = (a_axis / 1000)

if isinstance(c_axis, pvl._collections.Units):
    # do some tests to guess units
    if c_axis.units.upper() == ("METERS" or "M"):
        c_axis = (c_axis.value / 1000)
    elif c_axis.units.upper() == ("KILOMETERS" or "KM"):
        c_axis = c_axis.value
    else:
       print("Unsupported units " + c_axis.units)
else:
    # Guess that the units are meters and convert to kilometers
    print("PolarRadius has no units attribute. Guessing meters...")
    c_axis = (c_axis / 1000)

# Overwrite earlier values for these variables by converting them to PVL class with units
a_axis = PUnits(a_axis, 'KILOMETERS')
b_axis = a_axis
c_axis = PUnits(c_axis, 'KILOMETERS')
mapscale = PUnits(mapscale, "METERS/PIXEL")
        

pds3label.append('IMAGE_MAP_PROJECTION', pvl.PVLModule({
    'MAP_PROJECTION_TYPE': mapprojectiontype,
    'A_AXIS_RADIUS': a_axis,
    'B_AXIS_RADIUS': b_axis,
    'C_AXIS_RADIUS': c_axis,
    # Included because PDS3 requires it
   'FIRST_STANDARD_PARALLEL': """N/A""",
    # Included because PDS3 requires it
   'SECOND_STANDARD_PARALLEL': """N/A""",
    'POSITIVE_LONGITUDE_DIRECTION': positivelongdir,
    'CENTER_LATITUDE': centerlatitude,
    'CENTER_LONGITUDE': centerlongitude,
    # Included because PDS3 requires it
   'REFERENCE_LATITUDE': """N/A""",
    # Included because PDS3 requires it
   'REFERENCE_LONGITUDE': """N/A""",
    'LINE_FIRST_PIXEL': 1,
    'LINE_LAST_PIXEL': isis3lbl['IsisCube']['Core']['Dimensions']['Lines'],
    'SAMPLE_FIRST_PIXEL': 1,
    'SAMPLE_LAST_PIXEL': isis3lbl['IsisCube']['Core']['Dimensions']['Samples'],
    'MAP_PROJECTION_ROTATION': 0.0,
    'MAP_RESOLUTION': mapresolution,
    'MAP_SCALE': mapscale,
    'MAXIMUM_LATITUDE': maximumlatitude,
    'MINIMUM_LATITUDE': minimumlatitude,
    'EASTERNMOST_LONGITUDE': easternmostlong,
    'WESTERNMOST_LONGITUDE': westernmostlong,
    'LINE_PROJECTION_OFFSET': lineprojectionoffset,
    'SAMPLE_PROJECTION_OFFSET': sampleprojectionoffset,
    'COORDINATE_SYSTEM_TYPE': """BODY-FIXED ROTATING""",
    # Included because PDS3 requires it
   'COORDINATE_SYSTEM_NAME': isis3lbl['IsisCube']['Mapping']['LatitudeType'].upper(),
    # Not required by PDS3 but included for compatibility with other software
   'PROJECTION_LATITUDE_TYPE': isis3lbl['IsisCube']['Mapping']['LatitudeType'].upper()
} ))


# Prepare the new PDS3 label for writing
# If out_name already exists, it will be overwritten
out_name = inputlbl.replace('.lbl', '_pds3.lbl')
print(out_name)

## DEBUG Only ##
# out_name = 'test_pds3_output.lbl'
# print(out_name)
################

# Write the PDS3 label to disk using pvl.dump and the PDS encoder
with open(out_name, 'w') as stream:
    pvl.dump(pds3label,out_name,cls=pvl.encoder.PDSLabelEncoder)

## HACK to remove the single quotes from the value of the "^IMAGE" keyword
#  Compile regular expressions for the "^IMAGE" and "'" strings
# Also use brute force to ensure that final PDS3 label uses CRLF line endings
imgpointer = re.compile('\^IMAGE')
singlequote = re.compile('\'')
lineending = re.compile('\r\n$')
with fileinput.input([out_name], inplace=True,) as f:
    for line in f:
        s = imgpointer.search(line)
        # Just to be careful,
        #  we only replace singlequotes on lines that contain "^IMAGE"
        if s:
            updated_line = singlequote.sub('', line)
            # Write the updated line back to the file
            #  and update the line ending characters
            l = lineending.search(updated_line)
            if not l:
                sys.stdout.write(updated_line.replace('\n', '\r\n'))
        else:
            # Else,just correct the line ending and write back to file
            l = lineending.search(line)
            if not l:
                sys.stdout.write(line.replace('\n', '\r\n'))
