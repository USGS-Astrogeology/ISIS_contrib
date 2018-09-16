"""Python script to compute the exterior orientation for a NADIR image
that views a specified ground point with North up.

This script requires the following packages: numpy, pandas, quaternion, numba
"""


import numpy as np
import pandas as pd
import quaternion, argparse, os, subprocess

def compute_position(ground_point, distance):
    bf_position = np.array(distance / np.linalg.norm(ground_point)) * ground_point
    return bf_position

# TODO actually compute this properly
def compute_rotation(ground_point):
    bf_instrument_rotation = np.quaternion(1,0,0,0)
    return bf_instrument_rotation

# TODO replace getkey calls with PVL library
def get_key(cube, name, object=None, group=None):
    command = [
            'getkey',
            'from={}'.format(cube),
            'keyword={}'.format(name)]
    if object:
        command.append('objname={}'.format(object))
    if group:
        command.append('grpname={}'.format(group))
    result = subprocess.run(command, stdout=subprocess.PIPE, check=True)
    return result.stdout

def get_table(cube, table_name, csv):
    command = [
            'tabledump',
            'from={}'.format(cube),
            'name={}'.format(table_name),
            'to={}'.format(csv)]
    subprocess.run(command, check=True)

def attach_table(cube, csv, table_name, label=None):
    command = [
            'csv2table',
            'to={}'.format(cube),
            'csv={}'.format(csv),
            'tablename={}'.format(table_name)]
    if label:
        command.append('label={}'.format(label))
    subprocess.run(command, check=True)

def create_rotation_label(file, frame, time, description=None):
    label =    'TimeDependentFrames = ({}, 1)'.format(frame)
    label += '\nCkTableStartTime    = {}'.format(time)
    label += '\nCkTableEndTime      = {}'.format(time)
    label += '\nCkTableOriginalSize = 1'
    label += '\nFrameTypeCode       = 3'
    if description:
        label += '\nDescription         = {}'.format(description)
    with open(file, 'w') as out:
        out.write(label)

def create_position_label(file, time, description=None):
    label += '\nSpkTableStartTime    = {}'.format(time)
    label += '\nSpkTableEndTime      = {}'.format(time)
    label += '\nSpkTableOriginalSize = 1'
    if description:
        label += '\nDescription          = {}'.format(description)
    with open(file, 'w') as out:
        out.write(label)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('Template',
                    help='The filename for the template cube to adjust the perspective of.')
parser.add_argument('Output', help='The filename of the output cube')
parser.add_argument('X', help='The X coordinate of the ground point', type=float)
parser.add_argument('Y', help='The Y coordinate of the ground point', type=float)
parser.add_argument('Z', help='The Z coordinate of the ground point', type=float)
parser.add_argument('--distance',
                    help='The distance from observer to the center of the body in km',
                    type=float, default=110)
parser.add_argument('--clean',
                    help='Remove temporary files on successful execution.',
                    action='store_true')

args = parser.parse_args()

template_image = args.Template
output_image = args.Output
ground_point = np.array([args.X, args.Y, args.Z])
image_basename = os.path.splitext(os.path.basename(output_image))[0]

body_rotation_csv = image_basename + '_body_rotation.csv'
inst_rotation_csv = image_basename + '_instrument_rotation.csv'
inst_position_csv = image_basename + '_instrument_position.csv'
temp_files = [body_rotation_csv, inst_rotation_csv, inst_position_csv]

print('Getting viewing geometry tables from {}'.format(template_image))

get_table(template_image, 'BodyRotation', body_rotation_csv)
get_table(template_image, 'InstrumentPointing', inst_rotation_csv)
get_table(template_image, 'InstrumentPosition', inst_position_csv)

print('Computing new viewing geometry')

position = compute_position(ground_point, args.distance)
rotation = compute_rotation(ground_point)

print('Creating output image: {}'.format(output_image))

subprocess.run(['cp', template_image, output_image])

print('Prepping viewing geometry to be attached to {}'.format(output_image))

out_rotation = pd.read_csv(inst_rotation_csv)
row = out_rotation.iloc[0]
quat_array = quaternion.as_float_array(rotation)
row['J2000Q0'] = quat_array[3]
row['J2000Q1'] = -quat_array[0]
row['J2000Q2'] = -quat_array[1]
row['J2000Q3'] = -quat_array[2]
out_rotation.to_csv(inst_rotation_csv, index=False)

out_position = pd.read_csv(inst_position_csv)
row = out_position.iloc[0]
row['J2000X'] = position[0]
row['J2000Y'] = position[1]
row['J2000Z'] = position[2]
out_position.to_csv(inst_position_csv, index=False)

# Write the identity rotation out to the body rotation table so that body_fixed=J2000.
# This saves a little bit of work because attached spice data is in J2000
body_rotation = pd.read_csv(body_rotation_csv)
row = body_rotation.iloc[0]
row['J2000Q0'] = 0
row['J2000Q1'] = -1
row['J2000Q2'] = 0
row['J2000Q3'] = 0
out_position.to_csv(body_rotation_csv, index=False)

# TODO write these out using an actual pvl library
body_frame = get_key(template_image, 'BODY_FRAME_CODE', object='NaifKeywords')
camera_frame = get_key(template_image, 'NaifFrameCode', group='Kernels')
body_rotation_label = image_basename + '_body_rotation.pvl'
inst_rotation_label = image_basename + '_instrument_rotation.pvl'
inst_position_label = image_basename + '_instrument_position.pvl'
temp_files += [inst_rotation_label, body_rotation_label]
create_rotation_label(body_rotation_label, body_frame,
                      body_rotation.iloc[0]['ET'],
                      description='created by compute_orientation.py')
create_rotation_label(inst_rotation_label, camera_frame,
                      out_rotation.iloc[0]['ET'],
                      description='created by compute_orientation.py')
create_position_label(inst_position_label,
                      out_position.iloc[0]['ET'],
                      description='created by compute_orientation.py')

print('Attaching new viewing geometry to {}'.format(output_image))

attach_table(output_image, body_rotation_csv,
             'BodyRotation', label=body_rotation_label)
attach_table(output_image, inst_rotation_csv,
             'InstrumentPointing', label=inst_rotation_label)
attach_table(output_image, inst_position_csv,
             'InstrumentPosition', label=inst_position_label)

if args.clean:
    print('Cleaning up')
    for file in temp_files:
        print('Removing temp file: {}'.format(file))
        os.remove(file)
print('----Complete!----')
