"""
Python script to compute the exterior orientation for a NADIR image
that views a specified ground point with North up.

This script takes a ground point in X, Y, Z body fixed coordinates and an
input template image. It then, adjusts the viewing the geometry of the template
image so that the ground point is in the center of the image and North is up
in the image. By default, the viewing positon is set to a reasonable distance
from the body, but this can be adjusted by the distance argument.

This script does not use a hash bang so it must be called via
`python compute_orientation.py <args>`.
"""

from __future__ import print_function, division
import numpy as np
import pandas as pd
import quaternion, argparse, os, subprocess, orientation


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('Template',
                    help='The filename for the template cube to adjust the perspective of.')
parser.add_argument('Output', help='The filename of the output cube')
parser.add_argument('X', help='The X coordinate of the ground point', type=float)
parser.add_argument('Y', help='The Y coordinate of the ground point', type=float)
parser.add_argument('Z', help='The Z coordinate of the ground point', type=float)
parser.add_argument('-d', '--distance',
                    help='The distance from observer to the center of the body in km',
                    type=float, default=110)
parser.add_argument('-c', '--clean',
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

orientation.get_table(template_image, 'BodyRotation', body_rotation_csv)
orientation.get_table(template_image, 'InstrumentPointing', inst_rotation_csv)
orientation.get_table(template_image, 'InstrumentPosition', inst_position_csv)

print('Computing new viewing geometry')

position = orientation.compute_position(ground_point, args.distance)
rotation = orientation.compute_rotation(ground_point)

print('Creating output image: {}'.format(output_image))

subprocess.run(['cp', template_image, output_image])

print('Prepping viewing geometry to be attached to {}'.format(output_image))

# We don't want any velocities so just take the quaternions and position
rotation_fields = ['J2000Q0', 'J2000Q1', 'J2000Q2', 'J2000Q3', 'ET']
position_fields = ['J2000X', 'J2000Y', 'J2000Z', 'ET']

out_rotation = pd.read_csv(inst_rotation_csv)
row = out_rotation.iloc[0]
quat_array = quaternion.as_float_array(rotation)
quat_array = quat_array/np.linalg.norm(quat_array)
row['J2000Q0'] = quat_array[0]
row['J2000Q1'] = -quat_array[1]
row['J2000Q2'] = -quat_array[2]
row['J2000Q3'] = -quat_array[3]
out_rotation[rotation_fields].to_csv(inst_rotation_csv, index=False)

out_position = pd.read_csv(inst_position_csv)
row = out_position.iloc[0]
row['J2000X'] = position[0]
row['J2000Y'] = position[1]
row['J2000Z'] = position[2]
out_position[position_fields].to_csv(inst_position_csv, index=False)

# Write the identity rotation out to the body rotation table so that body_fixed=J2000.
# This saves a little bit of work because attached spice data is in J2000
body_rotation = pd.read_csv(body_rotation_csv)
row = body_rotation.iloc[0]
row['J2000Q0'] = 1
row['J2000Q1'] = 0
row['J2000Q2'] = 0
row['J2000Q3'] = 0
body_rotation[rotation_fields].to_csv(body_rotation_csv, index=False)

# TODO write these out using an actual pvl library
body_frame = orientation.get_key(
        template_image, 'BODY_FRAME_CODE', object='NaifKeywords')
camera_frame = orientation.get_key(
        template_image, 'NaifFrameCode', group='Kernels')
body_rotation_label = image_basename + '_body_rotation.pvl'
inst_rotation_label = image_basename + '_instrument_rotation.pvl'
inst_position_label = image_basename + '_instrument_position.pvl'
temp_files += [inst_rotation_label, body_rotation_label, inst_position_label]
orientation.create_rotation_label(
        body_rotation_label, body_frame,
        body_rotation.iloc[0]['ET'],
        description='created by compute_orientation.py')
orientation.create_rotation_label(
        inst_rotation_label, camera_frame,
        out_rotation.iloc[0]['ET'],
        description='created by compute_orientation.py')
orientation.create_position_label(
        inst_position_label,
        out_position.iloc[0]['ET'],
        description='created by compute_orientation.py')

print('Attaching new viewing geometry to {}'.format(output_image))

orientation.attach_table(
        output_image, body_rotation_csv,
        'BodyRotation', label=body_rotation_label)
orientation.attach_table(
        output_image, inst_rotation_csv,
        'InstrumentPointing', label=inst_rotation_label)
orientation.attach_table(
        output_image, inst_position_csv,
        'InstrumentPosition', label=inst_position_label)

if args.clean:
    print('Cleaning up')
    for file in temp_files:
        print('Removing temp file: {}'.format(file))
        os.remove(file)
print('----Complete!----')
