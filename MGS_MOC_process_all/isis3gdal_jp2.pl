#!/usr/bin/perl -s
###############################################################################
#
#_TITLE  isis3gdal_jp2.pl - Simple scirpt to create a GeoJpeg2000 
#                             from an ISIS3 file.
#
# Requires ISIS 3 and gdal_translate with JP2KAK encoder
#
#_ARGS  
#
#_Parm  Input filename
#
#_USER  Command line entry options [optional parameters]:
#
#   isis3gdal_jp2.pl [-q=75] [-f] [-s=8|16] [-p=rgg] input.cub output.jp2
#
# Requirements:
#
#   - images should be level 2 (map projected)
#
# Examples: 
#
#_DESC Convert an ISIS 3 cube to a GeoJpeg2000 file.
#
#      Options:
#       1) Jpeg2000 quality (-q=percentage (1 to 100), defaults to 100)
#             Default: 100
#       2) -f if 32bit, force image to 16bit in GDAL
#       3) -s=8|16 Stretch output to 8 or 16bit using isis2raw automatic stretch at 0.5%-99.5%
#       4) -p=rgg This is for HiRISE Anaglyphs to map band 1,2,2 to rgb.
#
#_FILE Input files utilized 
#	- 
#
#_LIMS  Design limitations
#        - General use
#    
#_CALL  List of calls:
#
#       List of external Perl modules
#          -none
#
#       List of ISIS programs that are called:
#         crop -  to convert to a BSQ raw image if needed
#        or
#         isis2raw -  to stretch to 16 or 8bit and convert to a BSQ raw image if needed
#
#       Unix utility: 
#         gdal_translate (from FWTools)
#
#_HIST
#       Aug 2005 - Trent Hare - Program rewritten from isis3world.pl
#
#_END
#########################################################################
######################################################################
# For help - user can enter this perl script and return
######################################################################
   if ($#ARGV < 0)
      {
      print " \n\n          *** HELP ***\n\n";
      print "isis3gdal_jp2.pl -  Create GeoJpeg2000 from an ISIS 3 cube\n\n";
      print "Command line: \n";
      print "  isis3gdal_jp2.pl [-q=1-100] [-f] [-s=8|16] [-p=rgg] input.cub output.jp2\n";
      print "\n    -q ; quality percentage, 1-100, defaults to 100 or lossless";
      print "\n    -f ; optional. if 32bit file, force truncation to 16bit in GDAL";
      print "\n    -s=8|16 ; automatic stretch to 8 or 16bit using linear stretch with range 0.5%-99.5%";
      print "\n    -p=rgg ; optional. rgg = red,green,green - meant to convert 2band anaglyphs to 3band output\n\n";
      exit 1;
      }

   $input = $ARGV[0];
   chomp $input;
   $output = $ARGV[1];
   chomp $output;

   if (!(-e $input)) {
      print "Input file does not exist: $input\n";
      exit 1;
   }
######################################################################
#  Check input file name for .cub extention
######################################################################

   @fname = split('\.',$input);
   $root = $fname[0];

   #  Create the header file from the bil file
   #print "$input";
   open INIMAGE, $input;

######################################################################
#  Check for quality flag. If none set to 100 or lossless
######################################################################
   if (!($q)) {
     $q = 100; 
   }

##################################################################
#  If the user set the -s=8|16 stretch flag, double check the entered values
#     8 and 16 are the only valid values.
##################################################################

   if ($s) {
     if ($s !=8 && $s != 16 && $s != 32)
       {
        print "[isis3gdal_jp2.pl-ERROR] Stretch switch must be set to 8 or 16\n";
        print " Example:  isis3gdal_jp2.pl -s=8 input.cub output.jp2\n";
        exit 1;
       }
     if ($f) {
        print "[isis3gdal_jp2.pl-ERROR] Only -s=8|16 or -f can be sent, not both\n";
        exit 1;
     }
   }


######################################################################
#  Check for system     - Not needed for this
######################################################################
#
#   $thesys = `uname`;
#   chomp $thesys;          #SunOS or Linux fo ISIS compatible systems
#

##################################################################
#Set ISIS NODATA
##################################################################
$NULL1=0;
$NULL2=-32768;
$NULL4=-0.3402822655089E+39;
#$NULL4=0xFF7FFFFB;

##################################################################
# Loop through image header to extract info
##################################################################
$flag = 0;
$xxTemp = "null";
while (<INIMAGE>) {

    ###############################################################
    # Extract the CORE_ITEM_BYTES
    ###############################################################
    if (/ Type /) {
      if ($flag ==0) { #This is a hacky fix to only find the first "Type" keyword
          @itp = split(/ = /,$_) ;
          $it = $itp[1];
          chomp $it;
          if ($it eq "UnsignedByte")  {
            $itype = 8;
            #Options U1,U2,U4,U8,U16,S16,U32,F32,F64
            $ERDASitype = "U8";
            #Options 8u,16U,16S,32R
            $PCIitype = "8U";
            $nodata = $NULL1;
          }
          elsif ($it eq "SignedWord") {
            $itype = 16;
            $ERDASitype = "S16";
            $PCIitype = "16S";
            $nodata = $NULL2;
          }
          elsif ($it eq "Real") {
            $itype = 32;
            $ERDASitype = "F32";
            $PCIitype = "32R";
            $nodata = $NULL4;

            if (!($f) && !($s))
            {
               print "\nThe current GDAL JP2KAK Jpeg2000 encoder does not allow 32bit files\n";
               print "  Please use the ISIS3 program stretch to convert to 8 or 16bit first\n";
               print "  or rerun using the '-f' switch to truncate to 16bit using GDAL\n";
               print "  or rerun using the '-s=8', '-s=16' switch to stretch to 8 or 16bit\n";
               print "  or rerun using the '-s=32'  switch to force 32bit output.  Not all formats support this.\n\n";
               exit 1;
            }
          }
          else { 
            $itype = 0; 
            $nodata = 0;
          }
      }
      $flag=1;
    }

   ###############################################################
   # Extract the FORMAT style if Tiled then convert
   ###############################################################
    if (/ Format /) {
        @ft = split(/ = /,$_) ;
        $format = $ft[1];
        chomp $format;
    }

    
    ##############################################################
    # Find the End
    ##############################################################
    if (/Object = Label/) {
       last;
    }

# End of image header loop
}

####################################################################
# Generate temporary raw file if needed
####################################################################
  if (($format eq "Tile") || ($s)) {
      @bname = split('\.',$input);
      $basename = @bname[0];
      if ($s) {
        $xxTemp = "$basename.raw";
        if ($s == 8) {
          $args = ("isis2raw from=$input to=$xxTemp bittype=8bit");
        }
        if ($s == 16) {
          $args = ("isis2raw from=$input to=$xxTemp bittype=s16bit");
        }
        if ($s == 32) {
          $args = ("isis2raw from=$input to=$xxTemp bittype=32bit");
        }
      } else {
        $xxTemp = "xxTemp_$basename.cub";
        print "[isis3gdal_jp2.pl-WARNING] Converting ISIS image to temporary BSQ first.\n";
        $args = ("crop from=$input to=$xxTemp+BandSequential");
        $input = $xxTemp;
      }
      print "submitting system command: $args\n";
      system($args) == 0
          or die "system $args failed: $?";
  }

####################################################################
# Generate jpeg2000 
####################################################################
  if ($q)
    {

       @ofname = split('\.',$input);
       $oroot = $ofname[0];
       $outprj = "$oroot.prj";
       $outaux = "$oroot.aux";

       $extra = "";
       if ($s) {
         $extra = "-o=$xxTemp,$s";
       }

       # check for HiRISE anaglyph switch
       if (!($p)) { 
         $p="-p";
       } else { #Pass through to set HiRISE special anaglyph mapping band 1,2,2 = rgb
         $p="-p=rgg";
         print "[isis3gdal_jp2.pl-WARNING] Setting anaglyph mode to map bands 1,2,2 to RGB\n";
       }
       if (-e isis3world.pl) {
         $args = ("./isis3world.pl $p -prj $extra $input");
       } else { #hope that isis3world.pl is in the environment path
         $args =   ("isis3world.pl $p -prj $extra $input");
       }
       print "submitting system command: $args\n";
       system($args) == 0
          or die "system $args failed: $?";

       ######################################################################
       #  "hidden" override to specify a different output gdal format, see gdal_translate
       ######################################################################
       if (!($of)) {
          $of = "JP2KAK"; 
       }

       if (($it eq "Real") && ($f) && (!($s))) {
         print "[isis3gdal_jp2.pl-WARNING] Truncating output to 16bit.\n";
         $args = ("gdal_translate -of $of -co \"quality=$q\" -ot Int16 -a_srs \"ESRI::$outprj\" -a_nodata $NULL2 $outaux $output");
       } elsif ($s==8) {
         $args = ("gdal_translate -of $of -co \"quality=$q\" -a_srs \"ESRI::$outprj\" -a_nodata $NULL1 $outaux $output");
       } elsif ($s==16) {
         $args = ("gdal_translate -of $of -co \"quality=$q\" -a_srs \"ESRI::$outprj\" -a_nodata $NULL2 $outaux $output");
       } else {
         $args = ("gdal_translate -of $of -co \"quality=$q\" -a_srs \"ESRI::$outprj\" -a_nodata $nodata $outaux $output");
       }
       print "submitting system command: $args\n";
       system($args) == 0
          or die "system $args failed: $?";

       if (-e $output) {
           print " $of file generated: $output\n\n";
           if (!($xxTemp eq "null")) {
              unlink($xxTemp);
           }
           #unlink($outprj);
           unlink($outaux);
       }

    }
