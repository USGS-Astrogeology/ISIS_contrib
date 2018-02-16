import cassis_process;

framelet = "$ISIS3TESTDATA/isis/src/tgo/tsts/uncontrolledSingleColorMosaic/input/CAS-MCO-2016-11-26T22.32.14.582-RED-01000-B1.xml"

framelet_list = ["/usgs/cpkgs/isis3/testData/isis/src/tgo/tsts/uncontrolledSingleColorMosaic/input/CAS-MCO-2016-11-26T22.32.14.582-RED-01000-B1.xml",
"/usgs/cpkgs/isis3/testData/isis/src/tgo/tsts/uncontrolledSingleColorMosaic/input/CAS-MCO-2016-11-26T22.32.15.582-RED-01001-B1.xml",
"/usgs/cpkgs/isis3/testData/isis/src/tgo/tsts/uncontrolledSingleColorMosaic/input/CAS-MCO-2016-11-26T22.32.16.582-RED-01002-B1.xml",
"/usgs/cpkgs/isis3/testData/isis/src/tgo/tsts/uncontrolledSingleColorMosaic/input/CAS-MCO-2016-11-26T22.32.17.582-RED-01003-B1.xml",
"/usgs/cpkgs/isis3/testData/isis/src/tgo/tsts/uncontrolledSingleColorMosaic/input/CAS-MCO-2016-11-26T22.32.18.582-RED-01004-B1.xml"]

map_filename = "equi.map"

# Ingest and spiceinit
print cassis_process.ingest_framelet(framelet, "ingested_framelet")
ingested_cubes = cassis_process.ingest_observation(framelet_list, "ingested_observation")

# Make the map file
cassis_process.make_map_file(ingested_cubes, map_filename)

# Project one framelet
framelet_cube = ingested_cubes[0]
projected_framelet_filename = framelet_cube.split('.')[0] + '_proj.cub'
cassis_process.project_framelet(framelet_cube, map_filename, projected_framelet_filename)

# Project an observation
projected_cubes = cassis_process.project_observation(ingested_cubes, "projected_observation", map_filename)
print projected_cubes

# Mosaic
cassis_process.mosaic_filter(projected_cubes, "mosaic.cub", map_filename)

# Export image
cassis_process.export_image(projected_cubes[0], "exported_cassis_framelet")

# Export mosaic
cassis_process.export_mosaic("mosaic.cub", "exported_cassis_mosaic")
