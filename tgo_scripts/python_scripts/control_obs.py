#!/usr/bin/env python

import sys, os, subprocess, argparse, cassis_process, shutil

parser = argparse.ArgumentParser(description='''This script takes a list of
    TGO CaSSIS framelets and created a controlled color mosaic from them.''')
parser.add_argument('input_list',
                    help="""The input list of XML labels for the framelets. For
                            each label there must be a raw image file with the
                            same name in the same directory.""")
parser.add_argument('working_directory',
                    help='The directory where output files will be made.')
parser.add_argument('def_file',
                    help='The definition file used to sub pixel register the networks')
parser.add_argument('reference_filter',
                    help="""The filter whose center framelet will be held fixed.
                            Valid options are RED, PAN, NIR, or BLU.""")
args = parser.parse_args()

# ensure that a valid filter was entered for the reference filter
valid_filters = ['RED', 'PAN', 'NIR', 'BLU']
if args.reference_filter not in valid_filters:
    print('Invalid reference filter entered.')
    exit()

# set the temp directory to be in the working_directory
cassis_process.temp_dir = os.path.join(args.working_directory, 'cassis_temp')

# save some working directories for future use
log_dir = os.path.join(args.working_directory, 'logs')
ingested_dir = os.path.join(args.working_directory, 'ingested')
adjusted_dir = os.path.join(args.working_directory, 'adjusted')
network_dir = os.path.join(args.working_directory, 'networks')
projected_dir = os.path.join(args.working_directory, 'projected')
mosaic_dir = os.path.join(args.working_directory, 'mosaics')

# open the input file
with open(args.input_list, 'r') as f:
    input_files = f.read().splitlines()

# ingest and spiceinit the cubes
ingested_cubes = cassis_process.ingest_observation(input_files, ingested_dir)

# sort out the different filters
filter_framelets = {'PAN' : [],
                    'RED' : [],
                    'NIR' : [],
                    'BLU' : []}
for cube in ingested_cubes:
    # get the filter keyword from the cube's instrument group
    filter_proc = subprocess.Popen(['getkey from={} objname=IsisCube grpname=Instrument keyword=Filter'.format(cube)],
                                   stdout=subprocess.PIPE, shell=True)
    (filter, err) = filter_proc.communicate()
    if err:
        message = 'Failed to get filter name from cube [{}]\n'.format(cube)
        message += '\n' + err
        print(message)
        exit()
    filter_framelets[filter.strip()].append(cube)

# generate a control net for each filter
filter_networks = []
for filter in filter_framelets:
    if not(filter_framelets[filter]):
        continue
    network_file = os.path.join(network_dir, '{}.net'.format(filter))
    status = cassis_process.generate_filter_control(filter_framelets[filter],
                                                    network_file,
                                                    filter,
                                                    log_dir)
    if status != 0:
        msg = 'Failed to generate control network for {} filter'.format(filter)
        print(msg)
        continue
    filter_networks.append(network_file)
    cassis_process.make_file_list(filter_framelets[filter], "{}_ingested.lis".format(filter))

# combine the individual filter networks
combined_net = os.path.join(network_dir, 'combined_filters.net')
status = cassis_process.combine_nets(filter_networks, combined_net, ingested_cubes, args.def_file)
if status != 0:
    print('Failed to combine control networks.')

# copy all of the ingested images into a new directory
if not os.path.exists(adjusted_dir):
    os.makedirs(adjusted_dir)
filter_adjusted = {'PAN' : [],
                   'RED' : [],
                   'NIR' : [],
                   'BLU' : []}
for filter in filter_framelets:
    for ingested_image in filter_framelets[filter]:
        image_basename = os.path.basename(ingested_image)
        adjusted_image = os.path.join(adjusted_dir, image_basename)
        shutil.copy(ingested_image, adjusted_dir)
        filter_adjusted[filter].append(adjusted_image)
adjusted_cubes = []
for filter in filter_adjusted:
    adjusted_cubes += filter_adjusted[filter]

# bundle adjust the network and update the pointing on the copied cubes
adjusted_net = os.path.join(network_dir, 'adjusted.net')
reference_filter_images = filter_adjusted[args.reference_filter]
if not reference_filter_images:
    print('No images for reference filter [{}]'.format(args.reference_filter))
    exit()
held_image = reference_filter_images[len(reference_filter_images)/2]
status = cassis_process.bundle_network(combined_net,
                                       adjusted_net,
                                       adjusted_cubes,
                                       held_image,
                                       os.path.join(log_dir, 'bundle'),
                                       1.0,
                                       True)
if status != 0:
    print('Failed to bundle adjust network')
    exit()

# map project the adjusted images
map_file = os.path.join(args.working_directory, 'adjusted_equi.map')
cassis_process.make_map_file(adjusted_cubes, map_file)
filter_projected = {}
for filter in filter_adjusted:
    if filter_adjusted[filter]:
        filter_projected[filter] = cassis_process.project_observation(filter_adjusted[filter],
                                                                      projected_dir,
                                                                      map_file)

# create the filter mosaics
filter_mosaics = {}
for filter in filter_projected:
    mosaic_file = os.path.join(mosaic_dir, '{}_equi.cub'.format(filter))
    cassis_process.mosaic_filter(filter_projected[filter], mosaic_file, map_file)
    filter_mosaics[filter] = mosaic_file

# register each mosaic to the reference mosaic
registered_mosaics = []
for filter in filter_mosaics:
    if filter != args.reference_filter:
        registered_mosaic = os.path.splitext(filter_mosaics[filter])[0] + '_reg.cub'
        registration_net = os.path.join(network_dir, '{}_reg_to_{}.net'.format(filter, args.reference_filter))
        cassis_process.coreg_image(filter_mosaics[filter],
                                   registered_mosaic,
                                   filter_mosaics[args.reference_filter],
                                   registration_net)
        registered_mosaics.append(registered_mosaic)
    else:
        registered_mosaics.append(filter_mosaics[filter])


# stack the mosaics
color_mosaic = os.path.join(mosaic_dir, 'COLOR_equi.cub')
cassis_process.stack_mosaics(registered_mosaics, color_mosaic)

# export the color mosaic
exported = os.path.join(mosaic_dir, 'COLOR_equi.img')
cassis_process.export_mosaic(color_mosaic, exported)
