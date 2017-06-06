# ISIS3 to PDS3 Label Translator #
``isis3_lbl_to_pds3_lbl.py`` is a rudimentary script for translated detached ISIS3 labels into detached PDS3 labels. 
The script was developed specifically to translate labels from high-level map-projected image products that are distributed on the USGS Astropedia
(<https://astrogeology.usgs.gov/search>). It is **not** a generic translator for ISIS3 labels.
The script aims to produce labels can best be described as "PDS3 compatible" if not strictly "PDS3 compliant." In practice, this means
that given a valid ISIS3 label for a map-projected image product, the script will return a PDS3 label that can be successfully interpreted by 
the ISIS3 program ``pds2isis``, as well as by geospatial software such as GDAL and QGIS.

## Dependencies ##
 - Python3
 - PVL library: <https://github.com/planetarypy/pvl>

## Basic Usage ##
Executing
``isis3_lbl_to_pds3_lbl.py input.lbl``
will parse generate an ISIS3 label named ``input.lbl`` and return a PDS3 label file named ``isis3_label_pds3.lbl``
