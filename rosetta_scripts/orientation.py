"""
Module for adjusting viewing geometry using ISIS3. This module requires that
the ISIS3 executables are in your PATH.
"""

import numpy as np
import pandas as pd
import quaternion, argparse, os, subprocess


"""
Compute the observer position given a ground point and distance

parameters
----------
ground_point : array
               The ground point that will be viewed in body fixed X, Y, Z
               as a numpy array.

distance : float
           The distance from the center of the body to the observer in kilometers.

returns
-------
position : array
           The observer position in body fixed X, Y, Z as a numpy array.
"""
def compute_position(ground_point, distance):
    bf_position = np.array(distance / np.linalg.norm(ground_point)) * ground_point
    return bf_position


"""
Compute the shortest rotation between two vectors.

parameters
----------

u : array
    The first vector that the rotation will rotate to v.

v : array
    The second vector that the rotation will rotate u to.

fallback : array
           When the input vectors are exactly opposite, there is not a unique
           shortest rotation between them. A 180 degree rotation about any axis
           will work. If this parameter is entered, then it will be used as the
           axis of rotation. Otherwise, the cross product of u and either the
           x-axis or y-axis will be used for the axis of rotation.

returns
-------
rotation : quaternion
           The output rotation from u to v.
"""
def rotation_between(u, v, fallback=None):
    tolerance = 1e-10

    if np.linalg.norm(u) < tolerance or np.linalg.norm(v) < tolerance:
        return np.quaternion(1,0,0,0)

    unit_u = u / np.linalg.norm(u)
    unit_v = v / np.linalg.norm(v)

    dot = np.dot(unit_u,unit_v)
    # If the vectors are within tolerance of parallel, return identity rotation
    if dot >  1.0 - tolerance:
        return np.quaternion(1,0,0,0)
    # If the vectors are within tolerance of opposite, return a 180 degree rotation
    # about an arbitrary perpendicular axis.
    # If no fall back axis is provided,
    # try the cross product of the x-axis and u.
    # If they are co-linear use the y-axis.
    elif dot < -1.0 + tolerance:
        if fallback is not None:
            axis = fallback
        else:
            axis = np.cross(unit_u, np.array([1,0,0]))
            if np.linalg.norm(axis) < tolerance:
                axis = np.cross(unit_u, np.array([0,1,0]))
        return np.quaternion(0, axis[0], axis[1], axis[2])

    axis = np.cross(unit_u, unit_v)
    scalar = 1 + dot
    return np.quaternion(scalar, axis[0], axis[1], axis[2])


"""
Compute the rotation from the body fixed reference frame to a NADIR view of
a ground point.

Parameters
----------
ground_point : array
               The ground point that will be viewed in body fixed X, Y, Z
               coordinates.

returns
-------
rotation : quaternion
           The rotation from body fixed to a NADIR view of the groung point.
           The body fixed Z+ vector will be rotated to the NADIR look vector.
"""
def compute_rotation(ground_point):
    x_plus = np.array([1,0,0])
    z_plus = np.array([0,0,1])
    look_vector = -ground_point / np.linalg.norm(ground_point)

    # First compute the rotation that takes +Z to the look vector
    look_rotation = rotation_between(z_plus, look_vector)

    # Next compute the rotation that aligns North up, the rotation that takes
    # the rotated +X to the component of +Z that is orthogonal the look vector.
    rotated_x = quaternion.as_rotation_matrix(look_rotation) @ x_plus
    north_up = z_plus - np.dot(z_plus, look_vector) * look_vector
    # We need to make sure that if the rotated x and north up vector are
    # opposites, then we use a 180 rotation about the look vector so as
    # to not screw it up
    north_rotation = rotation_between(rotated_x, north_up, look_vector)
    return north_rotation * look_rotation


# TODO replace getkey calls with PVL library
"""
Get a key from the label of an ISIS3 cube file.

parameters
----------
cube : str
       The filename of the cube to get the key from.

name : str
       The name of the key to get from the cube label.

object : str
         The name of the Pvl object containing the key. If not entered,
         defaults to the root object.

group : str
        The name of the Pvl group containing the key. If not entered,
        defaults to searching for keys that are not contained in any group.

returns
-------
value : str
        The value of the key.
"""
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
    return result.stdout.strip().decode()


"""
Write a table from an ISIS3 cube file to a CSV file.

parameters
----------
cube : str
       The filename of the cube to get the table from.

table_name : str
             The name of the table to get from the cube.

csv : str
      The filename of the CSV file to write to.
"""
def get_table(cube, table_name, csv):
    command = [
            'tabledump',
            'from={}'.format(cube),
            'name={}'.format(table_name),
            'to={}'.format(csv)]
    subprocess.run(command, check=True)


"""
Write a table from a CSV file to an ISIS3 cube file.

parameters
----------
cube : str
       The filename of the cube to write the table to.

csv : str
      The filename of the CSV file to get the data from.

table_name : str
             The name of the table to write to the cube.

label : str
        Optional flat PVL file whose keywords will be added to the table label.
"""
def attach_table(cube, csv, table_name, label=None):
    command = [
            'csv2table',
            'to={}'.format(cube),
            'csv={}'.format(csv),
            'tablename={}'.format(table_name)]
    if label:
        command.append('label={}'.format(label))
    subprocess.run(command, check=True)


"""
Create a flat PVL lable file for a rotation quaternion table.

parameters
----------
file : str
       The filename of the PVL file to write out.

frame : str
        The NAIF frame code that the quaternion rotates to.

time : str
       The ephemeris time for the rotation.

description : str
              Optional description that will be added to the label.
"""
def create_rotation_label(file, frame, time, description=None):
    label =    'TimeDependentFrames = ({}, 1)'.format(frame)
    label += '\nCkTableStartTime    = {}'.format(time)
    label += '\nCkTableEndTime      = {}'.format(time)
    label += '\nCkTableOriginalSize = 1'
    label += '\nFrameTypeCode       = 3'
    if description:
        label += '\nDescription         = "{}"'.format(description)
    label += '\n\nEnd'
    with open(file, 'w') as out:
        out.write(label)


"""
Create a flat PVL lable file for a position table.

parameters
----------
file : str
       The filename of the PVL file to write out.

time : str
       The ephemeris time for the position.

description : str
              Optional description that will be added to the label.
"""
def create_position_label(file, time, description=None):
    label =    'SpkTableStartTime    = {}'.format(time)
    label += '\nSpkTableEndTime      = {}'.format(time)
    label += '\nSpkTableOriginalSize = 1'
    if description:
        label += '\nDescription          = "{}"'.format(description)
    label += '\n\nEnd'
    with open(file, 'w') as out:
        out.write(label)
