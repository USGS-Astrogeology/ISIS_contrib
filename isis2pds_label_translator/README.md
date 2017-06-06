# ISIS3 to PDS3 Label Translator #
``isis3_lbl_to_pds3_lbl.py`` is a rudimentary script for translating detached ISIS3 labels into detached PDS3 labels. 
The script was developed specifically to translate labels from high-level map-projected image products that are distributed on the USGS Astropedia
(<https://astrogeology.usgs.gov/search>). 

The translator requires a very specific set of keywords (mostly map projection parameters), allows for a specific set of optional keywords, and ignores everything else in the input. It is **not** a generic translator for ISIS3 labels.

The script aims to produce labels can best be described as "PDS3 compatible" if not strictly "PDS3 compliant." In practice, this means
that given a valid ISIS3 label for a map-projected image product, the script will return a PDS3 label that can be successfully interpreted by 
the ISIS3 program ``pds2isis``, as well as by geospatial software such as GDAL and QGIS.

## Dependencies ##
 - Python3
 - PVL library: <https://github.com/planetarypy/pvl>

## Example ##
The script takes a single detached ISIS3 label as input. There are numerous ways to generate this input label. The following example illustrates how to use GDAL (version >=2.2.0) to convert an ISIS3 cube with attached label into a GeoTIFF with detached ISIS3 label and then pass this to the label translator. The ``test_data`` subdirectory contains copies of the input used in the following example and the resulting output:

``gdal_translate -of ISIS3 -co USE_SRC_MAPPING=YES -co DATA_LOCATION=GEOTIFF Triton_Voyager2_Sinusoidal_Airbrush_Mosaic_1472m.cub Triton_Voyager2_Sinusoidal_Airbrush_Mosaic_1472m.lbl``

``isis3_lbl_to_pds3_lbl.py Triton_Voyager2_Sinusoidal_Airbrush_Mosaic_1472m.lbl``
will parse the ISIS3 label and return a PDS3 label file named ``Triton_Voyager2_Sinusoidal_Airbrush_Mosaic_1472m_pds3.lbl``
