LROC_process_all.csh
```
LROC Narrow Angle image processing in ISIS3 to map projected images
-Trent Hare


Requires: 
**ISIS3 installed properly and in your path



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
>LROC_process_all.csh simp0.map 1 
where usage is: LROC_process_all.script.txt maptemplate.map [0|1] 
0 = keep all files as you go 
1 = delete old files as you go 

```