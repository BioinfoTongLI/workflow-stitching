import json
import logging
import xml.etree.ElementTree as ET

import fire
import numpy as np
import pandas as pd
import skimage.exposure as exposure
import tifffile
from glob import glob
from natsort import natsorted
from os.path import join
from pystackreg import StackReg
from skimage.exposure import rescale_intensity
from tifffile import TiffFile, imwrite
from warnings import filterwarnings

filterwarnings("ignore")

logging.basicConfig(level=logging.INFO)


def get_registration_matrixlist(beadstack1: str, beadstack2: str, channel_config: pd.DataFrame) -> List[np.ndarray]:
    """
    Get registration matrices for each channel in the configuration.

    Args:
        beadstack1 (str): Path to the beadstack file for camera 1.
        beadstack2 (str): Path to the beadstack file for camera 2.
        channel_config (pd.DataFrame): DataFrame containing the channel configuration.

    Returns:
        list: List of transformation matrices for each channel.
    """
    with TiffFile(beadstack1) as tif1:
        volume1 = tif1.asarray()
        axes1 = tif1.series[0].axes

    with TiffFile(beadstack2) as tif2:
        volume2 = tif2.asarray()
        axes2 = tif2.series[0].axes

    proj1 = axes1.find("Z")
    zproj1 = np.max(volume1, axis=proj1)

    proj2 = axes2.find("Z")
    zproj2 = np.max(volume2, axis=proj2)

    transf_matr_list = []
    for regpc, regchn in zip(channel_config.RegPC, channel_config.RegChN):
        if regpc == 1:
            ch_array = rescale_intensity(zproj1[regchn, :, :])
        elif regpc == 2:
            ch_array = rescale_intensity(zproj2[regchn, :, :])
        else:
            raise ValueError("RegPC should be either 1 or 2!")

        if not transf_matr_list:
            ref_ch = ch_array
        else:
            sr = StackReg(StackReg.AFFINE)
            tr_mat = sr.register(ref_ch, ch_array)
            transf_matr_list.append(tr_mat)

    return transf_matr_list


def get_zproj_tile_cam2(tiff_series, nz_planes, n_ch, n_tile):
    """
    Get the z-projected tile for camera 2.

    Args:
        tiff_series (list): List of TiffFile objects for camera 2.
        nz_planes (int): Number of z-planes.
        n_ch (int): Number of channels.
        n_tile (int): Tile index.

    Returns:
        np.ndarray: Z-projected tile for camera 2.
    """
    frame_start = nz_planes * n_ch * n_tile
    size_img = tiff_series[0].asarray().shape
    img = np.zeros((n_ch, nz_planes, size_img[0], size_img[1]))
    for chn in range(n_ch):
        for zpl in range(nz_planes):
            img[chn, zpl, :, :] = tiff_series[frame_start].asarray()
            frame_start += 1
    img_zproj = np.max(img, axis=1)
    return img_zproj


def metadata_values(json_data, xml_data):
    """
    Get metadata values from JSON and XML data.

    Args:
        json_data (dict): JSON data.
        xml_data (xml.etree.ElementTree.Element): XML data.

    Returns:
        tuple: Tuple containing pixel size, position list, name list, and channel list.
    """
    pos_list = []
    name_list = []
    pixelsize = [
        xml_data[1][3].attrib["PhysicalSizeX"],
        xml_data[1][3].attrib["PhysicalSizeY"],
        xml_data[1][3].attrib["PhysicalSizeZ"],
    ]
    channels = json_data["ChNames"]
    for i in range(json_data["Positions"]):
        pos_list.append(
            json_data["StagePositions"][i]["DevicePositions"][0]["Position_um"]
        )
        name_list.append(xml_data[i + 1].attrib["Name"])
    return (pixelsize, pos_list, name_list, channels)


def write_tileconfig(pos_list, export_dir):
    """
    Write the TileConfiguration.txt file.

    Args:
        pos_list (list): List of positions.
        export_dir (str): Path to the export directory.
    """
    outfile = join(export_dir, "TileConfiguration.txt")
    output = open(outfile, "w")
    output.write("dim=2\n")
    tile_no = len(pos_list)
    for i in range(tile_no):
        tile_string = "{};;({},{})\n".format(
            i, -1 * pos_list[i][0], -1 * pos_list[i][1]
        )
        output.write(tile_string)
    output.close


def get_pixel_attrib(file_path):
    """
    Get pixel attributes from a TIFF file.

    Args:
        file_path (str): Path to the TIFF file.

    Returns:
        list: List containing pixel size and units.
    """
    with TiffFile(file_path) as fh:
        ome_md = fh.ome_metadata

    root = ET.fromstring(ome_md)
    NS = {"ome": "http://www.openmicroscopy.org/Schemas/OME/2016-06"}
    for md in root.findall("ome:Image", NS):
        pixels = md.find("ome:Pixels", NS)
        pixelsize_x = float(pixels.attrib["PhysicalSizeX"])
        pixelsize_y = float(pixels.attrib["PhysicalSizeY"])
        pixelunit_x = pixels.attrib["PhysicalSizeXUnit"]
        pixelunit_y = pixels.attrib["PhysicalSizeYUnit"]
    pix = [pixelsize_x, pixelsize_y, pixelunit_x, pixelunit_y]
    return pix


def register_and_save_tiles(FolderPC1File, FolderPC2, TransfMatrList, ChConfig, OutDir):
    """
    Register and save tiles.

    Args:
        folder_pc1_file (str): Path to the first Tiff file of Camera 1 with all metadata.
        folder_pc2 (str): Path to the images from Camera 2.
        transf_matr_list (list): List of transformation matrices for each channel.
        channel_config (pd.DataFrame): DataFrame containing the channel configuration.
        out_dir (str): Path to the output directory.
    """
    # here I assume that order of images recorded is the same as order of their names
    filelist2 = glob(join(FolderPC2, "*.tif"))
    filelist2 = natsorted(filelist2)

    with TiffFile(filelist2[0]) as tif2:
        Ser_cam2 = tif2.series[0]
        shp = list(tifffile.TiffFile(filelist2[0]).series[0].shape)
        Ntiles_cam2 = shp[0]
        NCh_cam2 = shp[1]
        NZpl_cam2 = shp[2]

    with TiffFile(FolderPC1File) as tif:
        imagej_metadata = tif.imagej_metadata
        metadata_info = imagej_metadata["Info"]
        info = json.loads(metadata_info)
        root = ET.fromstring(tif.pages[0].tags[270].value)  # why 270???
        pixelsize, poslist, namelist, channels = metadata_values(info, root)

        ntile = 0
        # go thourgh each tile, register and save it
        for tile in tif.series:
            pc1_volume = tile.asarray()
            pc1_axes = tile.axes
            pc1_projax = pc1_axes.find("Z")
            pc1_zproj = np.max(pc1_volume, axis=pc1_projax)

            # get zprojected tile from camrera 2
            pc2_zproj_tile = get_zproj_tile_cam2(Ser_cam2, NZpl_cam2, NCh_cam2, ntile)
            # go through all channels and register them (except ref channel)
            nch = 0
            NewTile = np.zeros(
                [len(ChConfig), np.shape(pc1_zproj)[-2], np.shape(pc1_zproj)[-1]],
                dtype=pc1_zproj.dtype,
            )
            sr = StackReg(StackReg.AFFINE)
            for exppc, expchn in zip(ChConfig.ExpPC, ChConfig.ExpChN):
                if exppc == 1:
                    ChArray = pc1_zproj[expchn, :, :]
                elif exppc == 2:
                    ChArray = pc2_zproj_tile[expchn, :, :]
                else:
                    print("ExpPC should be either 1 or 2!")

                if nch == 0:
                    NewTile[0, :, :] = ChArray
                    nch = nch + 1
                else:
                    NewTile[nch, :, :] = sr.transform(
                        ChArray, tmat=TransfMatrList[nch - 1]
                    )
                    nch = nch + 1

            outname = "Tile{:04d}.tif".format(ntile)
            outfile = join(OutDir, outname)

            metadata = {
                "axes": "CYX",
                "Channel": {"Name": list(ChConfig.Name)},
                "PhysicalSizeX": pixelsize[0],
                "PhysicalSizeXUnit": "µm",
                "PhysicalSizeY": pixelsize[1],
                "PhysicalSizeYUnit": "µm",
            }

            print("Writing tile " + str(ntile), end="\r")
            imwrite(
                outfile,
                NewTile,
                imagej=True,
                resolution=(1.0 / float(pixelsize[0]), 1.0 / float(pixelsize[1])),
                metadata=metadata,
                ome=True,
            )
            ntile += 1
    tif.close()
    print("Tile saving is done!")
    write_tileconfig(poslist, OutDir)


def main(folder_pc1_file, folder_pc2, beadstack1, beadstack2, config_file, out_dir):
    """
    Main function.

    Args:
        folder_pc1_file (str): Path to the first Tiff file of Camera 1 with all metadata.
        folder_pc2 (str): Path to the images from Camera 2.
        beadstack1 (str): Path to the beadstack file for camera 1.
        beadstack2 (str): Path to the beadstack file for camera 2.
        config_file (str): Path to the channel configuration file.
        out_dir (str): Path to the output directory.
    """
    channel_config = pd.read_csv(config_file, sep="\t")
    transf_mat = get_registration_matrixlist(beadstack1, beadstack2, channel_config)
    register_and_save_tiles(folder_pc1_file, folder_pc2, transf_mat, channel_config, out_dir)


if __name__ == "__main__":
    fire.Fire(main)
