#!/bin/csh 
#MOCna (narrow angle) semi-batch Processing
#Trent Hare, July 2009
#update Oct 2009 to remove isis3gdal_jp2.pl which
# means your GDAL binaries must have ISIS3 support.
# Also updated for new commandline rules at ISIS 3.1.21 Release 2009/09/16
#
#Before running you must first create a map file.
#Use ISIS3's "maptemplate" program to create *.map.
#Here is the listing for a minimal N. Pole projection:
#mag{197}> cat npolar90.map
#Group = Mapping
#  ProjectionName  = PolarStereographic
#  CenterLongitude = 0.0
#  CenterLatitude  = 90.0
#End_Group
#End
#

if ($#argv != 2) then
   echo 
   echo "Usage: $0 maptemplate.map [0|1]"
   echo "0 = keep all files as you go"
   echo "1 = delete old files as you go"
   goto done
endif

##                  save command line args in variables
set map=$1
set del=$2
echo "running $0 with isis3 maptemplate=$map"

##run moc2isis
foreach i (*.imq)
  set base=`basename $i .imq`
  set new="$base.cub"
  echo moc2isis "from=$i to=$new"
  moc2isis from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end


##run spiceinit
foreach i (*.cub)
  echo spiceinit "from=$i"
  spiceinit from=$i
end

##run moccal 
foreach i (*.cub)
  set base=`basename $i .cub`
  set new="$base.lev1.cub"
  echo moccal "from=$i to=$new"
  moccal from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

## Maybe run mocnoise50 and mocevenodd
## Test for crosstrack summing mode=1
## Even if not run copy file to output for next step ".leveo.cub"
foreach i (*.lev1.cub)
  set base=`basename $i .lev1.cub`
  set temp="$base.lev1ct.cub"
  set new="$base.lev1eo.cub"
  set crosstrack=0
  echo "getkey from=$i grpn=Instrument keyword=CrosstrackSumming"
  set crosstrack=`getkey from=$i grpn=Instrument keyword=CrosstrackSumming`
  echo "crosstrack value: $crosstrack"
  if ($crosstrack != 1) then
    echo cp "from=$i to=$new"
    cp $i $new
  else #run mocnoise50 and mocevenodd
    echo mocnoise50 "from=$i to=$temp"
    mocnoise50 from=$i to=$temp
    echo mocevenodd "from=$temp to=$new"
    mocevenodd from=$temp to=$new
  endif
  if (-e $new && $del) then
    /bin/rm $i
    /bin/rm $temp
  endif
end


##run cam2map 
foreach i (*.lev1eo.cub)
  set base=`basename $i .lev1eo.cub`
  set new="$base.lev2.cub"
  echo cam2map "from=$i map=$map to=$new"
  cam2map from=$i map=$map to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

##run isis2std
foreach i (*.lev2.cub)
  set base=`basename $i .lev2.cub`
  set new="$base.png"
  #Only send base name to isis2std to help with extension issue
  echo "isis2std from=$i to=$base"
  isis2std from=$i to=$base
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

##For GDAL GeoJpeg2000 export - needs isis3gdal_jp2.pl and isis3world.pl
##contact Trent Hare for details
##run isis3gdal_jp2.pl
#foreach i (*.lev2.cub)
#  set base=`basename $i .lev2.cub`
#  set new="$base.jp2"
  #Only send base name to isis2std to help with extension issue
#  echo isis3gdal_jp2.pl $i $new
#  isis3gdal_jp2.pl -s=8 $i $new
#  if (-e $new && $del) then
#    /bin/rm $i
#  endif
#end

echo complete $0

done:
  exit 0

