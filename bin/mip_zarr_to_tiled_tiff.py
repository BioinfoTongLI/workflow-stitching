#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2022 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""

"""
import fire
from ome_zarr.reader import Reader
from ome_zarr.io import parse_url
from pathlib import Path
import xml.etree.ElementTree as ET
from glob import glob
import numpy as np
import tifffile as tf
import dask.array as da
import pysnooper
import natsort


NS = {"ome": "http://www.openmicroscopy.org/Schemas/OME/2016-06"}


def convert_SI(val, unit_in, unit_out):
    SI = {"micron": 0.000001, "µm":0.000001, "mm": 0.001, "cm": 0.01, "m": 1.0, "km": 1000.0}
    if val == 0.0:
        return 0
    return val * SI[unit_in] / SI[unit_out]


def get_position_list_from_ET(et_obj):
    pos_list = []
    for md in et_obj:
        #         print(md.attrib)
        pixels = md.find("ome:Pixels", NS)
        pixelsize_x = float(pixels.attrib["PhysicalSizeX"])
        pixelsize_y = float(pixels.attrib["PhysicalSizeY"])
        pixelunit_x = pixels.attrib["PhysicalSizeXUnit"]
        pixelunit_y = pixels.attrib["PhysicalSizeYUnit"]
        img_attrib = pixels.find("ome:Plane", NS).attrib
        #         print(img_attrib)
        #     print(img_attrib["PositionX"], img_attrib["PositionXUnit"])
        #     print(img_attrib["PositionY"], img_attrib["PositionYUnit"])

        posX_micron = convert_SI(
            float(img_attrib["PositionX"]), img_attrib["PositionXUnit"], "micron"
        )
        posY_micron = convert_SI(
            float(img_attrib["PositionY"]), img_attrib["PositionYUnit"], "micron"
        )
        posX_pix = int(posX_micron / pixelsize_x)
        posY_pix = int(posY_micron / pixelsize_y)
        pos = (posY_pix, posX_pix, pixelsize_x, pixelsize_y, pixelunit_x, pixelunit_y)
        pos_list.append(pos)
    return pos_list


def get_position_list(md):
    NS = {"ome": "http://www.openmicroscopy.org/Schemas/OME/2016-06"}
    root = ET.fromstring(md)
    print(root)
    image_mds = root.findall("ome:Image", NS)
    pos_list = []
    for img_md in image_mds:
        #         print(img_md)
        img_attrib = img_md.find("ome:Pixels", NS)[5].attrib
        #         print(img_attrib)
        posX_micron = convert_SI(
            float(img_attrib["PositionX"]), img_attrib["PositionXUnit"], "micron"
        )
        posY_micron = convert_SI(
            float(img_attrib["PositionY"]), img_attrib["PositionYUnit"], "micron"
        )
        posX_pix = int(posX_micron / calib)
        posY_pix = int(posY_micron / calib)
        pos = (posY_pix, posX_pix)
        if pos not in pos_list:
            pos_list.append(pos)
    #         print(f"{posY_pix} um, {posX_pix} um")
    return pos_list

@pysnooper.snoop()
def write_tiled_tif(imgs, pos_list, out, select_range):
    end = len(imgs) if int(select_range[1]) == -1 else int(select_range[1])
    with tf.TiffWriter(out, bigtiff=True) as tif:
        for i in range(int(select_range[0]), int(end)):
            img = imgs[i]
            n_ch = img.shape[0]
            pos_y, pos_x, pixelsize_x, pixelsize_y, pixelunit_x, pixelunit_y = pos_list[
                i
            ]
            metadata = {
                'Pixels': {
                    'PhysicalSizeX': pixelsize_x,
                    'PhysicalSizeXUnit': pixelunit_x,
                    'PhysicalSizeY': pixelsize_y,
                    'PhysicalSizeYUnit': pixelunit_y,
                },
                'Plane': {
                    'PositionX': [pos_x * pixelsize_x] * n_ch,
                    'PositionY': [pos_y * pixelsize_y] * n_ch,
                },
            }
            tif.write(img.astype(np.uint16), metadata=metadata)


def load_zarr(zarr_path):
    reader = Reader(parse_url(Path(zarr_path)))
    return list(reader())[0].data


@pysnooper.snoop()
def phenix(zarr_in, out_tif, select_range):
    wells = glob(f"{zarr_in}/[A-Z]/[0-9]")
    tree = ET.parse(f"{zarr_in}/OME/METADATA.ome.xml")
    root = tree.getroot()

    pos_list = get_position_list_from_ET(root.findall("ome:Image", NS))
    z = load_zarr(wells[0])
    mip_img = (
        z[0]
        .map_blocks(lambda block: np.max(block, axis=2).squeeze(), dtype=z[0].dtype)
        .compute()
    )
    raveled_mips = mip_img.reshape(-1, *mip_img.shape[-3:])[:len(pos_list)]

    write_tiled_tif(raveled_mips, pos_list, out_tif, select_range)


@pysnooper.snoop()
def nemo1(zarr_in, out_tif, select_range, correction_matrix=None):
    tiles = natsort.natsorted(glob(f"{zarr_in}/[!OME]*"))
    tree = ET.parse(f"{zarr_in}/OME/METADATA.ome.xml")
    root = tree.getroot()

    pos_list = get_position_list_from_ET(root.findall("ome:Image", NS))

    raveled_mips = []
    for t in tiles:
        tile = load_zarr(t)[0]
        if correction_matrix:
            # channel abberation correction
            tile = correct(tile, correction_matrix)
        mip_img = np.max(tile, axis=2).squeeze()
        raveled_mips.append(mip_img)
    raveled_mips = da.array(raveled_mips).compute()
    write_tiled_tif(raveled_mips, pos_list, out_tif, select_range)


if __name__ == "__main__":
    fire.Fire({
        "nemo1": nemo1,
        "phenix": phenix,
    })
