"""
This module contains functions for working with TGO CaSSIS images.
"""

import os, subprocess

# temporary directory for storing list files
temp_dir = 'cassis_temp'

def make_file_list(files, list_filename):
    """
    Write a python list of files to a list file witch each element on a new line.

    Parameters
    ----------
    files : list
            List of files to write to the file list.

    list_filename : str
                    The name of the list file to make.
                    If any of the parent directories do not exist,
                    they will be made.
    """
    list_dir = os.path.dirname(list_filename)
    if list_dir and not(os.path.exists(list_dir)):
        os.makedirs(list_dir)
    with open(list_filename, 'w') as f:
        for file in files:
            f.write('{}\n'.format(file))

def ingest_framelet(filename, output_dir):
    """
    Ingest a TGO CaSSIS framelet image and attach SPICE data to it

    Parameters
    ----------
    filename : str
               The filename of the XML label of the image to ingest.
               This must include the absolute or relative path to the file.
               The output cube will have the same basename.

    output_dir : str
                 The directory where the output cube will be.

    Returns
    -------
    output_filename : str
               The filename of the output cube.
               Including the absolute or relative path.
    """

    basename =  os.path.basename(filename)
    output_filename = basename[:-4] + ".cub" # Assume it ends in a .xml
    print output_filename

    if not(os.path.exists(output_dir)):
        os.system("mkdir {}".format(output_dir))

    output_filename = os.path.join(output_dir, output_filename)

    ingest_command = "tgocassis2isis from={} to={}".format(filename, output_filename)
    spiceinit_command = "spiceinit ckpredict=true spkpredict=true from={}".format(output_filename)

    os.system(ingest_command)
    os.system(spiceinit_command)

    return output_filename


def ingest_observation(filenames, output_dir):
    """
    Ingest a TGO CaSSIS observation and attach SPICE data to the images

    Parameters
    ----------
    filenames: list
               A list of the filenames to ingest
    output_dir: str
                The directory that the output cubes will be in

    Returns:
    --------
    output_filenames: list
                      A list of the filenames of the output cubes
    """

    if not(os.path.exists(output_dir)):
        os.makedirs(output_dir)

    output_filenames = []

    for filename in filenames:
        output_filename = ingest_framelet(filename, output_dir)
        output_filenames.append(output_filename)

    return output_filenames


def match_framelets(base, train, output_network, network_id, point_id, log=''):
    """
    Match two framelets and generate a control network.

    Parameters
    ----------
    base : str
           The base image to match the other image against

    train : str
            The image that will be matched to the base image

    output_network : str
                     The output control network file

    network_id : str
                 The ID for the output control network

    point_id : str
               The control point ID format.
               Expected format is some_prefix????,
               the question marks will be replaced with the point number.

    log : str
          The optional debug log file

    Returns
    -------
    status : int
             The return status of the matching application
    """
    command = 'findfeatures algorithm=sift/sift'
    command += ' match={}'.format(base)
    command += ' from={}'.format(train)
    command += ' onet={}'.format(output_network)
    command += ' networkID={}'.format(network_id)
    command += ' pointID="{}"'.format(point_id)
    if log:
        command += ' debug=true debuglog="{}"'.format(log)
    return os.system(command)


def generate_filter_control(images, output_network, filter, log_dir=''):
    """
    Match all of the framelets for a single filter and create a control network.

    Parameters
    ----------
    images : list
             List of images sorted by adjacency

    output_network : str
                     The name of the output control network

    filter : str
             The name of the filter

    log_dir : str
              The optional directory for log files

    Returns
    -------
    status : int
             The return status of the matching application
    """
    # make sure all of the directories exist
    network_dir = os.path.dirname(output_network)
    if network_dir and not(os.path.exists(network_dir)):
        os.makedirs(network_dir)
    if log_dir and not(os.path.exists(log_dir)):
        os.makedirs(log_dir)

    # match sequential framelets
    framelet_nets = []
    for index in range(0, len(images) - 1):
        base = images[index]
        train = images[index+1]
        network_id = '{}_{}_{}'.format(filter, index, index+1)
        network = os.path.join(network_dir, network_id + ".net")
        point_id = network_id + "????"
        log = ''
        if log_dir:
            log = os.path.join(log_dir, network_id + '.log')
        status = match_framelets(base, train, network, network_id, point_id, log)
        if status != 0:
            msg = 'Failed to match framelets [{}] and [{}]'.format(base, train)
            print(msg)
            return status
        framelet_nets.append(network)

    # combine the individual networks
    framelet_nets_file = os.path.join(temp_dir, "nets.lis")
    make_file_list(framelet_nets, framelet_nets_file)
    command = 'cnetmerge clist={}'.format(framelet_nets_file)
    command += ' onet={}'.format(output_network)
    command += ' network={}'.format(filter)
    command += ' description="network for the {} filter"'.format(filter)
    status = os.system(command)
    os.remove(framelet_nets_file)
    return status


def combine_nets(networks, combined_net, images, def_file, clean=True):
    """
    Combine a list of networks into one single network.
    This method will also attempt to add depth to the network.

    Parameters
    ----------
    networks : list
               The list of networks to combine

    combined_net : str
                   The output combined network.
                   If any of the parent directories do not exist, they will be created.

    images : list
             A list of all the images contained in the networks

    def_file : str
               The def file used with pointreg to sub-pixel register the combined network.

    clean : bool
            If the final network should have mesaures that failed to be registered removed.
            Defaults to True

    Returns
    -------
    status : int
             The return status of the applications.
    """
    # make file lists of the networks and images
    networks_file_list = os.path.join(temp_dir, "nets.lis")
    images_file_list = os.path.join(temp_dir, "images.lis")
    make_file_list(networks, networks_file_list)
    make_file_list(images, images_file_list)

    # make sure the output directory exists
    output_dir = os.path.dirname(combined_net)
    if output_dir and not(os.path.exists(output_dir)):
        os.makedirs(output_dir)

    # make the inbetween file names
    output_basename = os.path.splitext(combined_net)[0]
    cnetcombinept_net = output_basename + '_combined.net'
    added_net = output_basename + '_added.net'
    if clean:
        regged_net = output_basename + '_regged.net'
    else:
        regged_net = combined_net

    # combine the networks
    combine_command = 'cnetcombinept cnetlist={}'.format(networks_file_list)
    combine_command += ' onet={}'.format(cnetcombinept_net)
    status = os.system(combine_command)
    if status != 0:
        print('failed to combine networks with command:')
        print(combine_command)
        return status

    # add the images for depth
    add_command = 'cnetadd fromlist={}'.format(images_file_list)
    add_command += ' cnet={}'.format(cnetcombinept_net)
    add_command += ' addlist={}'.format(images_file_list)
    add_command += ' onet={}'.format(added_net)
    status = os.system(add_command)
    if status != 0:
        print('Failed to create depth in the combined network with command:')
        print(add_command)
        return status

    # sub-pixel register the newly added points
    pointreg_command = 'pointreg fromlist={}'.format(images_file_list)
    pointreg_command += ' cnet={}'.format(added_net)
    pointreg_command += ' onet={}'.format(regged_net)
    pointreg_command += ' deffile={}'.format(def_file)
    status = os.system(pointreg_command)
    if status != 0:
        print('Failed to sub pixel register network with command:')
        print(pointreg_command)
        return status

    # optionally remove measures that failed to be registered
    if clean:
        clean_command = 'cnetedit cnet={}'.format(regged_net)
        clean_command += ' onet={}'.format(combined_net)
        status = os.system(clean_command)
        if status != 0:
            print('Failed to clean network with command:')
            print(clean_command)
            return status

    # clean up
    os.remove(networks_file_list)
    os.remove(images_file_list)
    return status


def bundle_network(network, output_network, images, held_image, log_prefix,
                   angle_sigma=1, update=True):
    """
    Bundle adjust a control network.

    Parameters
    ----------
    network : str
              The input control network file to adjust

    output_network : str
                     The output adjusted control network file.

    images : list
             The list of images in the network.

    held_image : str
                 The image to hold fixed.

    log_prefix : str
                 The prefix for the bundle output files.

    angle_sigma : float
                  The sigma value for the camera angles in the bundle.

    update : bool
             If the images will have their camera pointing updated. Defaults to True.

    Returns
    -------
    status : int
             The return status of the jigsaw application.
    """
    # make sure the output and log directories exists
    output_dir = os.path.dirname(output_network)
    if output_dir and not(os.path.exists(output_dir)):
        os.makedirs(output_dir)
    log_dir = os.path.dirname(log_prefix)
    if log_dir and not(os.path.exists(log_dir)):
        os.makedirs(log_dir)

    # make the input file lists
    images_file_list = os.path.join(temp_dir, 'images.lis')
    make_file_list(images, images_file_list)
    held_list = [held_image]
    held_file_list = os.path.join(temp_dir, 'held.lis')
    make_file_list(held_list, held_file_list)


    # run the bundle adjustment
    bundle_command = 'jigsaw fromlist={}'.format(images_file_list)
    bundle_command += ' heldlist={}'.format(held_file_list)
    bundle_command += ' cnet={}'.format(network)
    bundle_command += ' onet={}'.format(output_network)
    bundle_command += ' camera_angles_sigma={}'.format(angle_sigma)
    bundle_command += ' file_prefix={}'.format(log_prefix)
    if update:
        bundle_command += ' update=true'
    status = os.system(bundle_command)
    if status != 0:
        print('Failed to bundle adjust network with command:')
        print(bundle_command)
        return status

    # clean up
    os.remove(images_file_list)
    os.remove(held_file_list)

    return status


def make_map_file(images, output_file):
    """
    Make a equirectangular map file that covers a list of images

    Parameters
    ----------
    images : list
             A list of cubes that will be contained in the map.

    output_file : str
                  The output map file name.
     """
    image_list_file = os.path.join(temp_dir, "mosrange.lis")
    make_file_list(images, image_list_file)

    mosrange_command = "mosrange fromlist={} to={}".format(image_list_file, output_file)
    os.system(mosrange_command)
    os.remove(image_list_file)


def project_framelet(image_file, map_file, output_file, trim=False):
    """
    Project a single framelet.

    Parameters
    ----------
    image_file : str
                 The framelet image file to project (cube)

    map_file : str
               The map file defining the projection

    output_file : str
                  The output projected file

    trim : bool
           If the projected file should be trimmed to just the projected data
    """

    # More complicated cam2map options needed?
    cam2map_command = "cam2map from={} to={} map={} pixres=map".format(image_file, output_file, map_file)
    os.system(cam2map_command)


def project_observation(filenames, output_dir, map_file, trim=False):
    """
    Project an entire observation. Output projected files will have '_proj'
    appended to their basename.


    Parameters:
    -----------
    filenames : list
                A list of the cube filenames to be projected

    output_dir: string
                The directory to put the projected cubes in

    map_file : string
               The map file definining the projection

    trim : bool
           If the projected file should be trimmed to just the projected data

    Returns:
    --------
    output_files : list
                   A list of the projected cubes created
    """
    if not(os.path.exists(output_dir)):
        os.makedirs(output_dir)

    output_files = []
    for image in filenames:
        basename =  os.path.basename(image)
        output_file = basename[:-4] + "_proj.cub"
        full_output_file = os.path.join(output_dir, output_file)
        project_framelet(image, map_file, full_output_file, trim)
        output_files.append(full_output_file)

    return output_files


def mosaic_filter(filenames, output_file, map_file=''):
    """
    Mosaic all of the framelets from a single filter.

    Parameters
    ----------
    filenames : str
                The filenames of the projected framelets to mosaic

    output_file : str
                  The filename of the output mosaic

    map_file : str
               Optional map file defining the extents of the mosaic.
               If not entered, the mosaic will made sufficiently large to
               contain the image data.
    """
    image_list_file = os.path.join(temp_dir, "framelets.lis")
    make_file_list(filenames, image_list_file)

    output_dir = os.path.dirname(output_file)
    if output_dir and not(os.path.exists(output_dir)):
        os.makedirs(output_dir)

    command = 'automos fromlist={} mosaic={}'.format(image_list_file, output_file)

    if map_file:
        if not os.path.exists(map_file):
            print('Map file [{}] does not exist'.format(map_file))
            os.remove(image_list_file)
            return

        min_lat_proc = subprocess.Popen(['getkey from={} keyword=MinimumLatitude grpname=Mapping'.format(map_file)],
                                        stdout=subprocess.PIPE, shell=True)
        (min_lat, err) = min_lat_proc.communicate()
        max_lat_proc = subprocess.Popen(['getkey from={} keyword=MaximumLatitude grpname=Mapping'.format(map_file)],
                                        stdout=subprocess.PIPE, shell=True)
        (max_lat, err) = max_lat_proc.communicate()
        min_lon_proc = subprocess.Popen(['getkey from={} keyword=MinimumLongitude grpname=Mapping'.format(map_file)],
                                        stdout=subprocess.PIPE, shell=True)
        (min_lon, err) = min_lon_proc.communicate()
        max_lon_proc = subprocess.Popen(['getkey from={} keyword=MaximumLongitude grpname=Mapping'.format(map_file)],
                                        stdout=subprocess.PIPE, shell=True)
        (max_lon, err) = max_lon_proc.communicate()

        command += ' grange=user minlat={} maxlat={} minlon={} maxlon={}'.format(min_lat.strip(),
                                                                                 max_lat.strip(),
                                                                                 min_lon.strip(),
                                                                                 max_lon.strip())

    os.system(command)

    os.remove(image_list_file)

def coreg_image(image, output_image, reference_image, output_network):
    """
    Subpixel register one image to another.

    Parameters
    ----------
    image : str
            The image to be registered

    output_image : str
                   The output registered image

    reference_image : str
                      The image to register to

    output_network : str
                     The output control network

    Returns
    -------
    status : int
             The return status of the coreg application
    """
    # ensure that output directories exist
    output_dir = os.path.dirname(output_image)
    if output_dir and not(os.path.exists(output_dir)):
        os.makedirs(output_dir)
    network_dir = os.path.dirname(output_network)
    if network_dir and not(os.path.exists(network_dir)):
        os.makedirs(network_dir)

    # do the registration
    command = 'coreg from={}'.format(image)
    command += ' to={}'.format(output_image)
    command += ' match={}'.format(reference_image)
    command += ' transform=warp onet={}'.format(output_network)
    status = os.system(command)
    if status != 0:
        print('Failed to sub pixel register image with command:')
        print(command)
    return status


def stack_mosaics(mosaics, output_file):
    """
    Stack single color mosaics into a full color mosaic.

    Parameters
    ----------
    mosaics : list
              List of mosaics files to stack.
              The stacked image bands will be in the same order as this list.

    output_file : str
                  The filename for the output stacked cube.
    """
    mosaic_list_file = os.path.join(temp_dir, "mosaics.lis")
    make_file_list(mosaics, mosaic_list_file)
    command = 'cubeit fromlist={} to={}'.format(mosaic_list_file, output_file)
    os.system(command)
    os.remove(mosaic_list_file)


def export_image(image, output_file):
    """
    Export a single framelet, projected or un-projected.

    Parameters
    ----------
    image : str
            The image file to export

    output_file : str
                  The name of exported PDS4 image file. A detached XML
                  label will also be created with the same name.

    Returns
    -------
    status : int
             The return status of the export application.
    """
    command = 'tgocassisrdrgen from={} to={}'.format(image, output_file)
    return os.system(command)

def export_mosaic(mosaic, output_file):
    """
    Export a mosaic.

    Parameters
    ----------
    mosaic : str
             The mosaic file to export

    output_file : str
                  The name of exported PDS4 image file. A detached XML
                  label will also be created with the export application.

    Returns
    -------
    status : int
             The return status of isis2pds.
    """
    command = 'isis2pds from={} to={} pdsversion=PDS4'.format(mosaic, output_file)
    return os.system(command)
