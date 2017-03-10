ISIS_scaledRadiusEquirectangular_Mars
============

_TITLE  ISIS_scaledRadiusEquirectangular_Mars.cpp

_ARGS  

_Parm  center_lat = center lattiude or standard_parallel for the map projection

_Parm  center_lon = center longitude. Shouldn't change the results. 
                            Just here since the map projection requires it

_DESC Calculate a scaled radius for the equirectangular projection
          emulating how USGS's ISIS3 does it.

_HIST
       Trent Hare - Program rewritten from ISIS3 source code

_LICENSE Public domain


Example runs:
```
> g++ -o ISIS_scaledRadiusEquirectangular_Mars ISIS_scaledRadiusEquirectangular_Mars.cpp

> ./ISIS_scaledRadiusEquirectangular_Mars 45 0
3386150.74700337  = Local Radius

> ./ISIS_scaledRadiusEquirectangular_Mars 45 45
3386150.74700337  = Local Radius

> ./ISIS_scaledRadiusEquirectangular_Mars 0 45
3396190.00000000  = Local Radius

> ./ISIS_scaledRadiusEquirectangular_Mars 90 45
3376200.00000000  = Local Radius

> ./ISIS_scaledRadiusEquirectangular_Mars 18 0
3394265.77471996  = Local Radius

> ./ISIS_scaledRadiusEquirectangular_Mars -14.5 0
3394926.37777623  = Local Radius
```