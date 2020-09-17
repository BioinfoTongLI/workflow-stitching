#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Generate the rendering.yml for each line of the tsv file
"""
import argparse
import pandas as pd
from dask_image.imread import imread
from apeer_ometiff_library import omexmlClass, io
import tifffile as tf
import numpy as np
import yaml


def generate_yaml(meas):
    img_path = "/".join([meas["location"], meas["filename"]])
    with tf.TiffFile(img_path, 'r') as fh:
        md = omexmlClass.OMEXML(fh.ome_metadata)

    pixels = md.image().Pixels
    ch_names = meas["Ch_names"].split("_")
    ch_names = ch_names[:pixels.SizeC]

    z_ind = int(np.floor(pixels.SizeZ/2))
    print(pixels.SizeZ, z_ind)

    # use default XYZCT
    dim_order = pixels.get_DimensionOrder()
    print(dim_order)
    target_z_indexes = np.arange(pixels.SizeC) * pixels.SizeZ + z_ind

    img = imread(img_path)
    ch_flag = "channels"
    yaml_content = {ch_flag:{}, "greyscale": False, "version": 2}
    default_colors = ["1E88E5", "D81B60", "FFC107", "004D40", "E66100", "4B0092", "994F00"]
    for i, ind in enumerate(target_z_indexes):
        current_setting = {}
        plane = img[ind].compute()
        win_start = int(np.percentile(plane, 1))
        win_end = int(np.percentile(plane, 98))
        print(win_start, win_end)
        current_setting["active"] = True
        current_setting["color"] = default_colors[i]
        current_setting["label"] = ch_names[i]
        current_setting["end"] = win_end
        current_setting["start"] = win_start

        yaml_content[ch_flag][i + 1] = current_setting
    with open(r'%s_render.yml' %meas["filename"], 'w') as file:
        documents = yaml.dump(yaml_content, file)
        print(documents)

def main(args):
    df = pd.read_csv(args.tsv, sep="\t")

    for idx in df.index:
        yml = generate_yaml(df.loc[idx])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-tsv", type=str,
            required=True)

    args = parser.parse_args()

    main(args)
