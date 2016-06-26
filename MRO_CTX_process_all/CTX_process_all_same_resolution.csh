#!/bin/csh 
#CTX semi-batch Processing
#Trent Hare, July 2007
#update Oct 2009 to remove isis3gdal_jp2.pl which
# means your GDAL binaries must have ISIS3 support.
#  Also updated for new commandline rules at ISIS 3.1.21 Release 2009/09/16
#update Oct 2012 to add support for lowercase extensions.
#  Also add web=true to use ISIS web service so that CTX kernels do not have to be local. 
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
   echo "Usage: $0 maptemplate.map [0|1]"
   echo "0 = keep all files as you go"
   echo "1 = delete old files as you go"
   goto done
endif

##                  save command line args in variables
set map=$1
set del=$2

##run mroctx2isis 
foreach i ( *.[Ii][Mm][Gg] )
  set base=`basename $i .IMG`
  set new="$base.cub"
  echo mroctx2isis "from=$i to=$new"
  mroctx2isis from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

##run spiceinit
##Here you might want to remove "web=true" if CTX SPICE is local
foreach i (*.cub)
  #echo spiceinit "from=$i"
  echo spiceinit "from=$i web=true"
  #spiceinit from=$i
  spiceinit from=$i web=true
end

##run ctxcal 
foreach i ( *.cub )
  set base=`basename $i .cub`
  set new="$base.lev1.cub"
  echo ctxcal "from=$i to=$new"
  ctxcal from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end


##run ctxevenodd 
foreach i (*.lev1.cub)
  set base=`basename $i .lev1.cub`
  set new="$base.lev1eo.cub"
  echo ctxevenodd "from=$i to=$new"
  ctxevenodd from=$i to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end


##run cam2map 
foreach i (*.lev1eo.cub)
  set base=`basename $i .lev1eo.cub`
  set new="$base.lev2.cub"
  echo cam2map "from=$i map=$map to=$new"
  cam2map from=$i map=$map pixres=map to=$new
  if (-e $new && $del) then
    /bin/rm $i
  endif
end

##run isis2std
foreach i (*.lev2.cub)
  set base=`basename $i .lev2.cub`
  set new="$base.png"
  #Only send base name to isis2std to help with extension issue
  echo isis2std "from=$i to=$base"
  isis2std from=$i to=$base
#  if (-e $new && $del) then
#    /bin/rm $i
#  endif
end

echo complete $0

done:
  exit 0

