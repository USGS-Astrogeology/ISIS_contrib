##Program:
** kaguyamiproc.pl ** - Ingest a PDS formatted Kaguya MI Level2B file and add map projection labels to it.


A Level 2B file will have these keywords in the label:

* PROCESS_VERSION_ID                   = "L2B"
* PRODUCER_ID                          = "LISM"
* PRODUCT_SET_ID                       = "MI-VIS_Level2B2"
* MISSION_NAME                         = "SELENE"
* SPACECRAFT_NAME                      = "SELENE-M"
* DATA_SET_ID                          = "MI-VIS_Level2B"
* INSTRUMENT_NAME                      = "Multiband Imager Visible"
* INSTRUMENT_ID                        = "MI-VIS"

* filename example: MVA_2B2_01_02024S140E3586.img

##ARGS  

Parm  inputfile = Input file name. This can either be a PDS formatted
       Kaguya MI image file or an ascii file containing a list of input 
       PDS formatted Kaguya MI image filenames. You must include the
       complete filename (no default extension is assumed). If you 
       provide a list, then each filename must be on a separate line
       in the list. If you are specifying a file list, then use the
       -l option to tell the script that it is a list.

##Command line entry options:

 kaguyamiproc.pl [-l] inputfile

 Examples:
 
    1) To process a single Kaguya MI file

        kaguyamiproc.pl input.img 

    2) To process a list of Kaguya MI files

        kaguyamiproc.pl -l input.lst

## HIST
    Jun 13 2011 - Janet Barrett - original version 
