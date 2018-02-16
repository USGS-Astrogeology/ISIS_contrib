#!/usr/bin/env python

import sys, os, subprocess, argparse, cassis_process

parser = argparse.ArgumentParser(description='''This script takes a list of
    TGO CaSSIS framelets and created a controlled color mosaic from them.''')
parser.add_argument('input_list',
                    help="""The input list of XML labels for the framelets. For
                            each label there must be a raw image file with the
                            same name in the same directory.""")
parser.add_argument('working_directory',
                    help='The directory where output files will be made.')
args = parser.parse_args()

# set the temp directory to be in the working_directory
cassis_process.temp_dir = os.path.join(args.working_directory, 'cassis_temp')

# open the input file
with open(args.input_list, 'r') as f:
    input_files = f.read().splitlines()

# ingest and spiceinit the cubes
ingested_dir = os.path.join(args.working_directory, 'ingested')
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

# generate control net for each filter
for filter in filter_framelets:
    network_file = os.path.join(args.working_directory, 'networks/{}.net'.format(filter))
    log_dir = os.path.join(args.working_directory, 'logs')
    status = cassis_process.generate_filter_control(filter_framelets[filter],
                                                    network_file,
                                                    filter,
                                                    log_dir)
    if status != 0:
        msg = 'Failed to generate control network for {} filter'.format(filter)
        print(msg)
        continue
    cassis_process.make_file_list(filter_framelets[filter], "{}_ingested.lis".format(filter))
