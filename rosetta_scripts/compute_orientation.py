"""Python script to compute the exterior orientation for a NADIR image
that views a specified ground point with North up.
"""


import numpy as np
import pandas as pd
import quaternion, argparse

def ground_point_to_bf_position(ground_point):
    bf_position = np.array(110 / np.linalg.norm(ground_point)) * ground_point
    return bf_position

def ground_point_to_bf_instrument_rotation(ground_point):
    bf_instrument_rotation = np.quaternion(1,0,0,0)
    return bf_instrument_rotation

# J2000 to body reference frame is in the body_rotation.csv file
def get_J2000_to_bf_rotation(csv):
    df = pd.read_csv(csv)
    row = df.iloc[0]
    # convert SPICE quaternion format to standard format (move scalar to end, negate vector components)
    j2000_bf_rotation = np.quaternion(-row['J2000Q1'], -row['J2000Q2'], -row['J2000Q3'], row['J2000Q0'])
    return j2000_bf_rotation

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('X', help='The X coordinate of the ground point', type=float)
parser.add_argument('Y', help='The Y coordinate of the ground point', type=float)
parser.add_argument('Z', help='The Z coordinate of the ground point', type=float)
parser.add_argument('--pointing-out',
                    help='The filename for the output instrument pointing CSV file.',
                    default='instrument_pointing.csv')
parser.add_argument('--position-out',
                    help='The filename for the output instrument position CSV file.',
                    default='instrument_position.csv')

args = parser.parse_args()

ground_point = np.array([args.X, args.Y, args.Z])

ground_point = np.array([5,5,25])

j2000_bf_rotation = get_J2000_to_bf_rotation('body_rotation.csv')
bf_position = ground_point_to_bf_position(ground_point)
bf_instrument_rotation = ground_point_to_bf_instrument_rotation(ground_point)

j2000_position = quaternion.as_rotation_matrix(j2000_bf_rotation) @ bf_position
j2000_instrument_rotation = bf_instrument_rotation * j2000_bf_rotation

out_rotation = pd.read_csv('base_instrument_pointing.csv')
row = out_rotation.iloc[0]
quat_array = quaternion.as_float_array(j2000_instrument_rotation)
row['J2000Q0'] = quat_array[3]
row['J2000Q1'] = -quat_array[0]
row['J2000Q2'] = -quat_array[1]
row['J2000Q3'] = -quat_array[2]
out_rotation.to_csv(args.pointing_out, index=False)

out_position = pd.read_csv('base_instrument_position.csv')
row = out_position.loc[0]
row['J2000X'] = j2000_position[0]
row['J2000Y'] = j2000_position[1]
row['J2000Z'] = j2000_position[2]
out_position.to_csv(args.position_out, index=False)
