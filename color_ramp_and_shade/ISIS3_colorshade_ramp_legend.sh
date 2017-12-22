# make sure you are running isis3!!!!
#
# By HiRISE Team (Sarah Mattson)
# slightly modified by Trent H.
# ISIS3_color_ramp_legend.sh input_dtm.cub

#For DEMs create hillshade (optional)
shade from=$1 to=shade.cub azimuth=45 zenith=30 #pixelresol=$2
stretch from=shade.cub to=shade_stretch.cub usepercentages=true pairs="1.0:0 99:255" lis=1 lrs=1 hrs=254 his=254

# These are not fully saturated RGB values but more medium saturated. It reads as 0% is mapped to the minimum value, 20% mapped to 20% of max - min...
# get elevation example: 60% mapped to =((max - min) * .60) + min
# 
# Here we is the GDAL mapping method we are emulating in ISIS (using stretch below)
# nv 0 0 0 //NoData maps to black
# 0% 255 120 255 //purple
# 20% 120 120 255 //blue
# 40% 120 255 255 //aqua
# 60% 120 255 120 //green
# 70% 255 255 120 //yellow
# 90% 255 120 120 //red
# 100% 255 255 255 //white

echo "0:255 20:120 40:120 60:120 70:255 90:255 100:255" > RED_stretch_pairs.txt
echo "0:120 20:120 40:255 60:255 70:255 90:120 100:255" > GREEN_stretch_pairs.txt
echo "0:255 20:255 40:255 60:120 70:120 90:120 100:255" > BLUE_stretch_pairs.txt

## Use these if using percentages in the stretch pairs file:
stretch from=$1 to=R usepercentages=true readfile=true inputfile=RED_stretch_pairs.txt
stretch from=$1 to=G usepercentages=true readfile=true inputfile=GREEN_stretch_pairs.txt
stretch from=$1 to=B usepercentages=true readfile=true inputfile=BLUE_stretch_pairs.txt

ls R.cub > RGB.lis
ls G.cub >> RGB.lis
ls B.cub >> RGB.lis
 
cubeit fromlist=RGB.lis to=RGB.cub

#For DEM, "add" with hillshade (optional), convert to jpeg
algebra from=RGB.cub from2=shade_stretch.cub to=color_shaded operator=add
isis2std red=color_shaded.cub+1 green=color_shaded.cub+2 blue=color_shaded.cub+3 to=color_shade.jpg mode=rgb format=jpeg minpercent=0 maxpercent=100 quality=90

# convert main image to jpeg
isis2std red=R.cub green=G.cub blue=B.cub to=RGB.jpg mode=rgb format=jpeg minpercent=0 maxpercent=100 quality=90

# create GeoTiff using GDAL - optional
#isis2std red=color_shaded.cub+1 green=color_shaded.cub+2 blue=color_shaded.cub+3 to=color_shaded.tif mode=rgb format=tiff minpercent=0 maxpercent=100
#gdal_copylabel.py color_shaded.tif color_shaded.cub color_shaded.vrt
#gdal_translate -co compress=lzw -co tiled=YES color_shaded.vrt color_shade_geo.tif
#/bin/rm -f color_shaded.tif
#/bin/rm -f color_shaded.vrt

# Make vertical color ramp (optional)
fakecube from=$1 to=fake option=linewedge
flip from=fake to=fake_flipped
reduce from=fake_flipped.cub to=fake_flipped_reduced.cub algorithm=average mode=total ons=200 onl=800

stretch from=fake_flipped_reduced.cub to=Ramp_R usepercentages=true readfile=true inputfile=RED_stretch_pairs.txt
stretch from=fake_flipped_reduced.cub to=Ramp_G usepercentages=true readfile=true inputfile=GREEN_stretch_pairs.txt
stretch from=fake_flipped_reduced.cub to=Ramp_B usepercentages=true readfile=true inputfile=BLUE_stretch_pairs.txt

# convert ramp image to jpeg
isis2std red=Ramp_R.cub green=Ramp_G.cub blue=Ramp_B.cub to=Ramp_RGB.jpg mode=rgb format=jpeg minpercent=0 maxpercent=100 quality=90

# Remove intermediate files
/bin/rm -f *stretch_pairs.txt
/bin/rm -f RGB.lis
/bin/rm -f R.cub G.cub B.cub
/bin/rm -f Ramp_R.cub Ramp_G.cub Ramp_B.cub
/bin/rm -f fake*.cub
/bin/rm -f shade.cub
