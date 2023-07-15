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
from glob import glob
import tifffile as tf
from ome_types import from_xml, to_xml, from_tiff
import pysnooper


NS = {"ome": "http://www.openmicroscopy.org/Schemas/OME/2016-06"}


@pysnooper.snoop()
def main(in_tif, out_tif, xml_name):
    if xml_name.endswith("ome.tif"):
        channel_names = ["DAPI", "max_proj", "ch1", "ch2", "ch3", "ch4"]
        ome = from_tiff(in_tif)
    else:
        ome = from_xml(xml_name, arser="lxml")
        channel_names = [ch.name for ch in ome.images[0].pixels.channels]
    ori_ome = from_tiff(in_tif)
    for i, ch in enumerate(ori_ome.images[0].pixels.channels):
        ch.name = channel_names[i]
    tf.tiffcomment(out_tif, to_xml(ori_ome).encode())

    # first_chs = []
    # ome.images = [ome.images[0]]
    # for plane in ome.images[0].pixels.planes:
    # if plane.the_z == 0 and plane.the_t == 0:
    # first_chs.append(plane)
    # ome.images[0].pixels.size_z = 1
    # ome.images[0].pixels.planes = first_chs

    # with tf.TiffFile(in_tif) as fh:
    # Y, X = fh.pages[0].shape
    # arr = fh.asarray()
    # ome.images[0].pixels.size_y = Y
    # ome.images[0].pixels.size_x = X
    # tf.imwrite(out_tif, arr, description=to_xml(ome).encode())


if __name__ == "__main__":
    fire.Fire(main)
