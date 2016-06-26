MOCna_process_all_jp2.csh
MOC Narrow Angle image processing in ISIS3 exporting to GeoJp2s.
-Trent Hare
July 2009


Requires: 
**ISIS3 installed properly and in your path
**isis3gdal_jp2.pl - PERL script which runs isis3world.pl and GDAL
**isis3world.pl - PERL script to gather header and projection information
**GDAL (for gdal_trasnlate with -jp2kak format support) placed in your path.  If you don't have -jp2kak support see step 4.


0.) Extract scripts. In UNIX run chmod to make the script executable. 
>chmod +x MOCna_process_all_jp2.csh 
>chmod +x isis3gdal_jp2.pl
>chmod +x isis3world.pl

1.) To help grab the MOC NA PDS images, use the PDS site, download the GIS footprints (I think this is the easiest) for use in a GIS or use pigwad to select the footprints you want. For the non-PDS methods, copy and paste the "DATA_LINK" files into a text file and prepend each line with "wget". Use the shapefile from
the coloection of MOC footprints called moc_footprints_0_100m.shp
example: 
wget http://www.msss.com/moc_gallery/e19_r02/imq/E21/E2101090.imq 
wget http://www.msss.com/moc_gallery/r16_r21/imq/R17/R1700641.imq 
... 

The MOC footprints: ftp://pdsimage2.wr.usgs.gov/pub/pigpen/mars/moc/footprints/ 


2.) Before running you must first create a map file. 
Use ISIS3's "maptemplate" program to create *.map. Here is the listing for a minimal N. Pole projection: 
>cat npolar90.map 
Group = Mapping 
  ProjectionName  = PolarStereographic 
  CenterLongitude = 0.0 
  CenterLatitude  = 90.0 
End_Group 
End 
--------------------------------------------------------------------------------

>cat simp0.map 
Group = Mapping
  ProjectionName     = SimpleCylindrical
  CenterLongitude    = 0.0
  LatitudeType       = Planetocentric
  LongitudeDirection = PositiveEast
  LongitudeDomain    = 180
End_Group
End
--------------------------------------------------------------------------------


Tip: this will leave it up to ISIS to figure out the cellsize. If you want to later run mosaics in ISIS3, you should force a cellsize (i.e. resolution=4 m/p) for all images in the maptemplate program. 

3.) run script: 
>MOCna_process_all_jp2.csh simp0.map 1 
where usage is: MOCna_process_all.script.txt maptemplate.map [0|1] 
0 = keep all files as you go 
1 = delete old files as you go 

4.) to change the output to another format see (simply make a change in the *.csh script for the isis3gdal_jp2.pl call):
http://isis.astrogeology.usgs.gov/IsisSupport/viewtopic.php?t=1456

5.) To setup GDAL in your path 
2.) download and untar FWTools-X.X.X on linux. 
- cd FWTools-X.X.X and run "./install.sh" 
- Place this directory ".../FWTools-X.X.X/bin_safe" into your path 

download: http://fwtools.maptools.org/ 

Whew...

good luck,
Trent
