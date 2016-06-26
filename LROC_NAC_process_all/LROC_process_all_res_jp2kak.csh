#!/bin/csh 
#LROC NA semi-batch Processing, ISIS version
#Trent Hare, July 2010
#
# This version requires PixelResolution in maptemplate
#
#Before running you must first create a map file.
#Use ISIS3's "maptemplate" program to create *.map.
#Here is the listing for a minimal N. Pole projection:
#mag{197}> cat npolar90.map
#Group = Mapping
#  ProjectionName  = PolarStereographic
#  CenterLongitude = 0.0
#  CenterLatitude  = 90.0
#  PixelResolution = 5.5 <meters/pixel>
#End_Group
#End
#
if ($#argv != 2) then
   echo "Usage: $0 maptemplate.map [0|1]"
   echo "0 = keep all files as you go"
   echo "1 = delete old files as you go"
   goto done
endif

##                  save command line args in variables
set map=$1
set del=$2

## change here is you need to manually set the DEM for ortho.
## this change also needs one more change below
#set DEM=/lro/lroc/TOPO/Kaguya_LALT_Nov09/ISIS3_radius/kaguya_LALT_radius_Simp180.cub

##run lronac2isis  
foreach i ( *.IMG )
  set base=`basename $i .IMG`
  set new="$base.cub"
  echo lronac2isis "from=$i to=$new"
  lronac2isis from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end


##run spiceinit
foreach i (*.cub)
  echo spiceinit "from=$i"
  ## To use your own DEM uncomment this line
  #spiceinit from=$i shape=user model=$DEM
  ## To use ISIS3 default DEM uncomment this line
  spiceinit from=$i
end

##run lronaccal  
foreach i ( *.cub )
  set base=`basename $i .cub`
  set new="$base.lev1.cub"
  echo lronaccal "from=$i to=$new"
  lronaccal from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

##run cam2map 
foreach i (*.lev1.cub)
  set base=`basename $i .lev1.cub`
  set new="$base.lev2.cub"
  echo cam2map "from=$i map=$map pixres=map to=$new"

  ##To process the same resolution, place pixres into .map and uncomment this version
  cam2map from=$i map=$map pixres=map to=$new
  ## Below will process all images to their optimal resolution (be different for each)
  #cam2map from=$i to=$new
  
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

##run conversion to jpeg2000 using gdal_translate
## use to be isis3gdal_jp2.pl
foreach i (*.lev2.cub)
  set base=`basename $i .lev2.cub`
  set isis8bit="$base.xxx8bit.cub"
  set stats="$base.xxxStats.txt"
  set new="$base.jp2"
  #echo isis3gdal_jp2.pl $i $new
  #isis3gdal_jp2.pl -s=8 $i $new

  #Try new approach to convert from ISIS3 to Jpg2000 using GDAL
  #since latest version of GDAL support ISIS directly
  if (-e $stats) then
    /bin/rm -f $stats
  endif
  #New to figure out min and max, several ways to do this
  #echo gdalinfo -stats $i > $stats
  gdalinfo -stats $i > $stats
  echo set min = `cat $stats | grep MINIMUM | awk -F= '{print $2}' | sed 's/ //g'`
  set min = `cat $stats | grep MINIMUM | awk -F= '{print $2}' | sed 's/ //g'`
  echo set max = `cat $stats | grep MAXIMUM | awk -F= '{print $2}' | sed 's/ //g'`
  set max = `cat $stats | grep MAXIMUM | awk -F= '{print $2}' | sed 's/ //g'`

  #convert to 8bit using ISIS and then use GDAL to convert to (kakadu jp2kak)
  #Kakadu encoding and comment the next couple of jp2ecw lines
  echo stretch from=$i to=$isis8bit+8bit+$min\:$max null=0 lis=0 lrs=0 his=255 hrs=255
  stretch from=$i to=$isis8bit+8bit+$min\:$max null=0 lis=0 lrs=0 his=255 hrs=255
  echo gdal_translate -ot byte -of jp2kak -co "quality=100" -a_nodata 0 $isis8bit $new
  gdal_translate -ot byte -of jp2kak -co "quality=100" -a_nodata 0 $isis8bit $new

  #convert to 8bit using ISIS and then convert to (ermapper jp2ecw)
  #echo stretch from=$i to=$isis8bit+8bit+$min\:$max null=0 lis=0 lrs=0 his=255 hrs=255
  #stretch from=$i to=$isis8bit+8bit+$min\:$max null=0 lis=0 lrs=0 his=255 hrs=255
  #echo gdal_translate -of jp2ecw -co "large_ok=TRUE" -co "target=0" -a_nodata 0 $isis8bit $new
  #gdal_translate -of jp2ecw -co "large_ok=TRUE" -co "target=0" -a_nodata 0 $isis8bit $new

  #clean up
  if (-e $stats) then
    /bin/rm -f $stats
  endif
  if (-e $isis8bit) then
    /bin/rm -f $isis8bit
  endif
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

echo complete $0

done:
  exit 0

