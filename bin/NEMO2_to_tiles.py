#! /usr/bin/env python3
from tifffile import TiffFile, TiffWriter, imwrite
from glob import glob
from os.path import split, join, isdir, isfile
import json
import xml.etree.ElementTree as ET
import numpy as np
from skimage.exposure import rescale_intensity, match_histograms, histogram
import csv
from pystackreg import StackReg
import pandas as pd
from ome_types import from_xml, to_xml, from_tiff
import tifffile
import fire
from natsort import natsorted


def get_registration_matrixlist(beadstack1, beadstack2, ChConfig):
    # set up registration matrices - expected only one tif file in each reg folder!!
    # regfile1_path = glob(join(FolderRegPC1, "*.tif"))
    # with TiffFile(regfile1_path[0]) as tif1:
    with TiffFile(beadstack1) as tif1:
        volume1 = tif1.asarray()
        axes1 = tif1.series[0].axes

    # regfile2_path = glob(join(FolderRegPC2, "*.tif"))
    # with TiffFile(regfile2_path[0]) as tif2:
    with TiffFile(beadstack2) as tif2:
        volume2 = tif2.asarray()
        axes2 = tif2.series[0].axes

    # z projection of reg images
    proj1 = axes1.find("Z")
    zproj1 = np.max(volume1, axis=proj1)
    proj2 = axes2.find("Z")
    zproj2 = np.max(volume2, axis=proj2)

    TransfMatrList = []
    nn = 0
    sr = StackReg(StackReg.AFFINE)
    for regpc, regchn in zip(ChConfig.RegPC, ChConfig.RegChN):
        if regpc == 1:
            ChArray = rescale_intensity(zproj1[regchn, :, :])
        elif regpc == 2:
            ChArray = rescale_intensity(zproj2[regchn, :, :])
        else:
            print("RegPC should be either 1 or 2!")

        if nn == 0:
            RefCh = ChArray
        else:
            TrMat = sr.register(RefCh, ChArray)
            TransfMatrList.append(TrMat)
        nn = nn + 1

    return TransfMatrList


def metadata_values(json_data, XML_data):
    poslist = []
    namelist = []
    pixelsize = [
        XML_data[1][3].attrib["PhysicalSizeX"],
        XML_data[1][3].attrib["PhysicalSizeY"],
        XML_data[1][3].attrib["PhysicalSizeZ"],
    ]
    channels = json_data["ChNames"]
    for i in range(json_data["Positions"]):
        poslist.append(
            json_data["StagePositions"][i]["DevicePositions"][0]["Position_um"]
        )
        namelist.append(XML_data[i + 1].attrib["Name"])
    return (pixelsize, poslist, namelist, channels)


def write_tileconfig(poslist, exportdir):
    outfile = join(exportdir, "TileConfiguration.txt")
    # print(outfile)
    output = open(outfile, "w")
    output.write("dim=2\n")
    tileno = len(poslist)
    for i in range(tileno):
        tilestring = "{};;({},{})\n".format(
            i, -1 * poslist[i][0], -1 * poslist[i][1]
        )  # why -1??
        output.write(tilestring)
    output.close


def get_pixel_attrib(file_path):
    with TiffFile(file_path) as fh:
        ome_md = fh.ome_metadata
    print(file_path)
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
    # here I assume that order of images recorded is the same as order of their names
    filelist2 = glob(join(FolderPC2, "*.tif"))
    filelist2 = natsorted(filelist2)

    with TiffFile(FolderPC1File) as tif:
        imagej_metadata = tif.imagej_metadata
        metadata_info = imagej_metadata["Info"]
        info = json.loads(metadata_info)
        root = ET.fromstring(tif.pages[0].tags[270].value)  # why 270???
        pixelsize, poslist, namelist, channels = metadata_values(info, root)

        nt = 0
        NPC2 = 0
        findex = 0
        # go thourgh each tile, register and save it
        for tile in tif.series:
            print(nt)
            pc1_volume = tile.asarray()
            pc1_axes = tile.axes
            pc1_projax = pc1_axes.find("Z")
            pc1_zproj = np.max(pc1_volume, axis=pc1_projax)

            # read one tif file from PC2 - it contains Nt number of tiles
            # if the previously opened PC2 tif file has no more tiles left
            if nt == 0:
                with TiffFile(filelist2[NPC2]) as tif2:
                    pc2_volume = tif2.asarray()
                    pc2axes = tif2.series[0].axes
                    pc2_projax = pc2axes.find("Z")
                    pc2_timeax = pc2axes.find("T")
                    if pc2_timeax > pc2_projax:
                        pc2_timeax = pc2_timeax - 1  # as z axes will be removed
                    pc2_zproj = np.max(pc2_volume, axis=pc2_projax)
                    NPC2 = NPC2 + 1  # count number for PC2 tif file

            # extract one timepoint=one tile from PC2 tif file
            pc2_zproj_tile = np.take(pc2_zproj, nt, axis=pc2_timeax)
            nt = nt + 1

            # check and if needed restart reading tif files from PC2 on the next tile iteration
            if nt > pc2_zproj.shape[0]:
                nt = 0

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

            outname = "Tile{:04d}.tif".format(findex)
            outfile = join(OutDir, outname)
            findex = findex + 1

            metadata = {
                "axes": "CYX",
                "Channel": {"Name": list(ChConfig.Name)},
                "PhysicalSizeX": pixelsize[0],
                "PhysicalSizeXUnit": "µm",
                "PhysicalSizeY": pixelsize[1],
                "PhysicalSizeYUnit": "µm",
            }

            print("Writing tile " + str(findex), end="\r")
            imwrite(
                outfile,
                NewTile,
                imagej=True,
                resolution=(1.0 / float(pixelsize[0]), 1.0 / float(pixelsize[1])),
                metadata=metadata,
                ome=True,
            )
    tif.close()
    del pc2_volume, pc1_volume
    print("Tile saving is done!")
    write_tileconfig(poslist, OutDir)


def main(FolderPC1File, FolderPC2, beadstack1, beadstack2, ConfigFile, OutDir):
    # FolderPC1FIle - path to the first tif file of Camera 1 with all metadata
    # FolderPC2 - folder to the images from PC2
    ChConfig = pd.read_csv(ConfigFile, sep="\t")
    TransfMat = get_registration_matrixlist(beadstack1, beadstack2, ChConfig)
    register_and_save_tiles(FolderPC1File, FolderPC2, TransfMat, ChConfig, OutDir)


if __name__ == "__main__":
    fire.Fire(main)
