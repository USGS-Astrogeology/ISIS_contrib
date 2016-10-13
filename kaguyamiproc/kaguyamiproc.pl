#!/usr/bin/perl 
#use -d in debugging mode
###############################################################################
###############################################################################
#
#_TITLE kaguyamiproc.pl - Ingest a PDS formatted Kaguya MI file and add 
#                         mapping labels to it.
#
#_ARGS  
#
#_Parm  inputfile = Input file name. This can either be a PDS formatted
#       Kaguya MI image file or an ascii file containing a list of input 
#       PDS formatted Kaguya MI image filenames. You must include the
#       complete filename (no default extension is assumed). If you 
#       provide a list, then each filename must be on a separate line
#       in the list. If you are specifying a file list, then use the
#       -l option to tell the script that it is a list.
#
#_USER  Command line entry options:
#
# kaguyamiproc.pl [-l] inputfile
#
# Examples:
#    1) To process a single Kaguya MI file
#
#        kaguyamiproc.pl input.img 
#
#    2) To process a list of Kaguya MI files
#
#        kaguyamiproc.pl -l input.lst
#
#_HIST
#    Jun 13 2011 - Janet Barrett - original version 
#
#_END
###############################################################################
###############################################################################
# Forces a buffer flush after every print, printf, and write on the
# currently selected output handle.  Let's you see output as it's 
# happening.
######################################################################
   $| = 1;
   
######################################################################
# Check to see if there is an argument passed to the procedure
######################################################################
   if ($#ARGV < 0) {
     print "\n\n   *** HELP ***\n\n";
     print "kaguyamiproc.pl - Ingest a PDS formatted Kaguya MI file and add mapping labels to it\n\n";
     print "Command line: \n";
     print "kaguyamiproc.pl [-l] inputfile\n";
     print "  -l = specify a list of file names\n";
     print "\nExamples:\n";
     print "  Process a single file:  kaguyamiproc.pl input.img\n";
     print "  Process a list of files:  kaguyamiproc.pl -l input.lst\n";
     exit 1;
   }

######################################################################
# Obtain the input parameters
######################################################################
   $input = $ARGV[0];
   chomp $input;
   if ($input eq "-l") {
     $list = $ARGV[1];
     chomp $list;
   } else {
     $list = "";
   }

######################################################################
# Better make sure input image/list exists
######################################################################
   if ($list ne "") {
     if (!(-e $list)) {
       print "*** ERROR *** Input list file does not exist: $list\n";
       exit 1;
     }
  } else {
    if (!(-e $input)) {
      print "*** ERROR *** Input image file does not exist: $input\n";
      exit 1;
    }
  }

######################################################################
# Process through each file in the list to determine what the 
# maximum map scale is. This is the map scale that each file will
# be scaled to in order for them to be mosaicked.
######################################################################
   $mapscale = 0.0;
   @lscale = ();
   @sscale = ();
   @lflag = ();
   @mnlon = ();
   @mxlon = ();
   @mnlat = ();
   @mxlat = ();
   @satmvdir = ();
   if ($list ne "") {
     open(LST,"<$list");

     while ($input=<LST>) {
       chomp($input);
       getmapscale($input);
     }
     close(LST);
   } else {
     getmapscale($input);
   }

######################################################################
# Process each file in the list so that it has a consistent mapping
# label on it
######################################################################
   $count = 0;
   if ($list ne "") {
     open(LST,"<$list");

     while ($input=<LST>) {
       chomp($input);
       addmaplbl($input);
       $count = $count + 1;
     }
     close(LST);
   } else {
     addmaplbl($input);
   }

###############################################################################
###############################################################################
# This subroutine imports the PDS file and determines its map scale
###############################################################################
###############################################################################
   sub getmapscale {
     $infile = $_[0];

     @fname = split('\.',$infile);
     $root = $fname[0];
     $extn = $fname[$#fname];

######################################################################
# First, convert the image file from PDS to ISIS format
######################################################################
     if ($extn ne "cub") {
       $outfile = $root . "_import.cub";
       if (-e $outfile) {unlink($outfile);}
       $cmd = "kaguyami2isis from=$infile to=$outfile";
       $ret = system($cmd);
       if ($ret) {
         print "*** ERROR *** Input image file could not be converted from PDS to ISIS: $input\n";
         exit 1;
       }
       $useinfile = 0;
     } else {
       $outfile = $infile;
       $useinfile = 1;
     }

######################################################################
# Second, get information from image labels 
######################################################################
     $nLines = `getkey from=$outfile grpname=Dimensions keyword=Lines`;
     chomp $nLines;
     $nSamples= `getkey from=$outfile grpname=Dimensions keyword=Samples`;
     chomp $nSamples;
     $ulLat = `getkey from=$outfile grpname=Instrument keyword=UpperLeftLatitude`;
     chomp $ulLat;
     $ulLon = `getkey from=$outfile grpname=Instrument keyword=UpperLeftLongitude`;
     chomp $ulLon;
     if ($ulLon < -180) {$ulLon = $ulLon + 360;}
     if ($ulLon > 180) {$ulLon = $ulLon - 360;}
     $urLat = `getkey from=$outfile grpname=Instrument keyword=UpperRightLatitude`;
     chomp $urLat;
     $urLon = `getkey from=$outfile grpname=Instrument keyword=UpperRightLongitude`;
     chomp $urLon;
     if ($urLon < -180) {$urLon = $urLon + 360;}
     if ($urLon > 180) {$urLon = $urLon - 360;}
     $llLat = `getkey from=$outfile grpname=Instrument keyword=LowerLeftLatitude`;
     chomp $llLat;
     $llLon = `getkey from=$outfile grpname=Instrument keyword=LowerLeftLongitude`;
     chomp $llLon;
     if ($llLon < -180) {$llLon = $llLon + 360;}
     if ($llLon > 180) {$llLon = $llLon - 360;}
     $lrLat = `getkey from=$outfile grpname=Instrument keyword=LowerRightLatitude`;
     chomp $lrLat;
     $lrLon = `getkey from=$outfile grpname=Instrument keyword=LowerRightLongitude`;
     chomp $lrLon;
     if ($lrLon < -180) {$lrLon = $lrLon + 360;}
     if ($lrLon > 180) {$lrLon = $lrLon - 360;}
     $locFlag = `getkey from=$outfile grpname=Instrument keyword=LocationFlag`;
     chomp $locFlag;
     $satmovedir = `getkey from=$outfile grpname=Instrument keyword=SatelliteMovingDirection`;
     chomp $satmovedir;

######################################################################
# Third, figure out the map scale to use for the entire list
######################################################################
#  Determine min/max lat/lon
     $minLat = $ulLat;
     $maxLat = $ulLat;
     $minLon = $ulLon;
     $maxLon = $ulLon;
     if ($urLat < $minLat) {$minLat = $urLat};
     if ($urLat > $maxLat) {$maxLat = $urLat};
     if ($urLon < $minLon) {$minLon = $urLon};
     if ($urLon > $maxLon) {$maxLon = $urLon};
     if ($llLat < $minLat) {$minLat = $llLat};
     if ($llLat > $maxLat) {$maxLat = $llLat};
     if ($llLon < $minLon) {$minLon = $llLon};
     if ($llLon > $maxLon) {$maxLon = $llLon};
     if ($lrLat < $minLat) {$minLat = $lrLat};
     if ($lrLat > $maxLat) {$maxLat = $lrLat};
     if ($lrLon < $minLon) {$minLon = $lrLon};
     if ($lrLon > $maxLon) {$maxLon = $lrLon};

# Determine latitude range and longitude range
     $latRange = $maxLat - $minLat;
     $lonRange = $maxLon - $minLon;
     
# Determine line and sample scale in pixels/degree
     $lineScale = $nLines / $latRange;
     $sampScale = $nSamples / $lonRange;

# Keep track of maximum map scale
     if ($lineScale > $mapscale) {
       $mapscale = $lineScale;
     }
     if ($sampScale > $mapscale) {
       $mapscale = $sampScale;
     }

# Determine resolution in meters/pixel
     $resolution = (2.0 * 3.14159265 * 1737400.0) / (360.0 * $mapscale);

     @lscale = (@lscale,$lineScale);
     @sscale = (@sscale,$sampScale);
     @lflag = (@lflag,$locFlag);
     @mnlon = (@mnlon,$minLon);
     @mxlon = (@mxlon,$maxLon);
     @mnlat = (@mnlat,$minLat);
     @mxlat = (@mxlat,$maxLat);
     @satmvdir = (@satmvdir,$satmovedir);
   }

###############################################################################
###############################################################################
# This subroutine enlarges the file to make the pixels square and adds the
# mapping labels
###############################################################################
###############################################################################
   sub addmaplbl {
     $infile = $_[0];

     @fname = split('\.',$infile);
     $root = $fname[0];

######################################################################
# First, enlarge the file
######################################################################
     if ($useinfile == 0) {
       $cubfile = $root . "_import.cub";
     } else {
       $cubfile = $infile;
     }

# Assume nonsquare pixels - line and sample scales are not
# equal (ISIS can't handle nonsquare pixels). Determine
# enlargement factor needed to make pixels square
     $enlargelinefactor = $mapscale / $lscale[$count];
     $enlargesamplefactor = $mapscale / $sscale[$count];

# Determine upper left X and Y of projection
     $upperleftX = $mnlon[$count] * $mapscale * $resolution;
     $upperleftY = $mxlat[$count] * $mapscale * $resolution;

# Enlarge the image
     $enlargefile = $root . "_enlarge.cub";
     if (-e $enlargefile) {unlink($enlargefile);}
     $cmd = "enlarge from=$cubfile to=$enlargefile interp=bilinear ";
     $cmd = $cmd . "mode=scale sscale=$enlargesamplefactor lscale=$enlargelinefactor";

     $ret = system($cmd);
     if ($ret) {
       print "*** ERROR *** Problem when enlarging file: $cubfile\n";
       exit 1;
     }
     if ($useinfile == 0) {unlink($cubfile);}

# Flip file left to right if the LocationFlag and SatelliteMovingDirection
# are set to one of the following: A/+1, D/-1, N/-1, S/-1, W/-1.
     $outfile = $enlargefile;
     $flipltor = 0;
     if (($lflag[$count] eq "A" && $satmvdir[$count] == 1) ||
         ($lflag[$count] eq "D" && $satmvdir[$count] == -1) ||
         ($lflag[$count] eq "N" && $satmvdir[$count] == -1) ||
         ($lflag[$count] eq "S" && $satmvdir[$count] == -1) ||
         ($lflag[$count] eq "W" && $satmvdir[$count] == -1)) {
       $mirrorfile = $root . "_mirror.cub";
       if (-e $mirrorfile) {unlink($mirrorfile);}
       $cmd = "mirror from=$enlargefile to=$mirrorfile";
       $ret = system($cmd);
       if ($ret) {
         print "*** ERROR *** Problem when mirror'ing file: $enlargefile\n";
         exit 1;
       }
       unlink($enlargefile);
       $flipltor = 1;
       $outfile = $mirrorfile;
     }

# Flip file top to bottom if the LocationFlag is set to Ascending
     if ($lflag[$count] eq "A") {
       $flipfile = $root . "_flip.cub";
       if (-e $flipfile) {unlink($flipfile);}
       $infile = $outfile;
       $cmd = "flip from=$infile to=$flipfile";
       $ret = system($cmd);
       if ($ret) {
         print "*** ERROR *** Problem when flipping file: $enlargefile\n";
         exit 1;
       }
       unlink($infile);
       $outfile = $flipfile;
     }
     $filename = $root . ".cub";
     system("mv $outfile $filename");
     $outfile = $filename;

######################################################################
# Fourth, add mapping group to image labels
######################################################################
     $cmd = "editlab from=$outfile options=addg grpname=Mapping";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=ProjectionName value=SimpleCylindrical";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=CenterLongitude value=0.0";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=TargetName value=Moon";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=EquatorialRadius value=1737400 units=meters";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=PolarRadius value=1737400 units=meters";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=LatitudeType value=Planetocentric";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=LongitudeDirection value=PositiveEast";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=LongitudeDomain value=180";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=UpperLeftCornerX value=$upperleftX units=meters";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=UpperLeftCornerY value=$upperleftY units=meters";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=PixelResolution value=$resolution units=meters/pixel";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=Scale value=$mapscale units=pixels/degree";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=MinimumLatitude value=$mnlat[$count]";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=MaximumLatitude value=$mxlat[$count]";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=MinimumLongitude value=$mnlon[$count]";
     $ret = system($cmd);
     $cmd = "editlab from=$outfile options=addkey grpname=Mapping ";
     $cmd = $cmd . "keyword=MaximumLongitude value=$mxlon[$count]";
     $ret = system($cmd);
   } 
