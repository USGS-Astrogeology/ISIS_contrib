/**************************************************************************
#
#_TITLE  ISIS_scaledRadiusEquirectangular_Mars.cpp
#
#_ARGS  
#
#_Parm  center_lat = center lattiude or standard_parallel for the map projection
#
#_Parm  center_lon = center longitude. Shouldn't change the results. 
#                            Just here since the map projection requires it
#
# Example run: 
#          ISIS_scaledRadiusEquirectangular_Mars 45.5 0
#
#_DESC Calculate a scaled radius for the equirectangular projection
#          emulating how USGS's ISIS3 does it.
#
#_HIST
#       Trent Hare - Program rewritten from ISIS3 source code
#
#_LICENSE Public domain
#
#_END
*******************************************************************/

#include <stdlib.h> 
#include <stdio.h> 
#include <math.h> 

int main(int argc, const char* argv[] )
{ 
  double a,b,c,PI; 
  double lat,lon,xyradius,radius; 
  PI = 4 * atan(1);

/***************************************************************** 
 * User Input
******************************************************************/ 
   if (argc != 3)
     {
      printf ("\nrerun program, and enter the required parameters:");
      printf ("\n%s center_lat center_lon \n\n",argv[0]);
      exit(1);
     }

    lat = atof(argv[1]);
    lon = atof(argv[2]);

/***************************************************************** 
 * Biaxial case for Mars_2000
******************************************************************/ 

    a = 3396190.0; 
    b = 3396190.0; 
    c = 3376200.0;
    lat = lat * PI / 180;  /* in radians */ 
    lon = lon * PI / 180;  /* in radians */ 

/*********************************************** 
 * Get the  scaling radius 
 ***********************************************/ 

    xyradius = a * b / sqrt(pow(b*cos(lon),2) + pow(a*sin(lon),2) ); 
    radius = xyradius * c / sqrt(pow(c*cos(lat),2) + pow(xyradius*sin(lat),2) ); 
    printf("%.8f  = Local Radius\n",radius); 
  } 

