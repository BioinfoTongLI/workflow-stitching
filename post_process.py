#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Rename the images in a PE stiched folder according to the log file
"""
import argparse
import pandas as pd
from glob import glob
import re
from pathlib import Path
import shutil
from dask_image.imread import imread
from apeer_ometiff_library import omexmlClass, io
import tifffile as tf
import numpy as np
import yaml


def generate_yaml(img_path, meas):
    with tf.TiffFile(img_path, 'r') as fh:
        md = omexmlClass.OMEXML(fh.ome_metadata)

    pixels = md.image().Pixels
    ch_prob_cols = [ind for ind in meas.index if ind.startswith("Channel")]
    tar_ch_cols = [s.replace("Channel", "Target") for s in ch_prob_cols]
    ch_maps = {meas[ch_prob] : meas[tar_ch_cols[i]]
            for i, ch_prob in enumerate(ch_prob_cols)
            if meas[ch_prob] != "nan"}

    ome_ch_names = pixels.get_channel_names()
    ch_names = [ch_maps[ch] for ch in ome_ch_names]
    print(ch_names)

    z_ind = int(np.floor(pixels.SizeZ/2))
    # print(pixels.SizeZ, z_ind)

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
        current_setting["active"] = True
        current_setting["color"] = default_colors[i]
        current_setting["label"] = ch_names[i]
        current_setting["end"] = 0
        try:
            plane = img[ind].compute()
            win_start, win_end = np.percentile(plane, [1, 99])
            print(win_start, win_end)
            current_setting["end"] = int(win_end)
            current_setting["start"] = int(win_start)
        except:
            current_setting["start"] = 500
            print("Dask image loading error, using default channel contrast setting")

        yaml_content[ch_flag][i + 1] = current_setting


def save_yaml(yaml_content, path):
    with open(r'%s.render.yml' %path, 'w') as file:
        documents = yaml.dump(yaml_content, file)
        print(documents)


def generate_omero_dataset(serie):
    SampleID = "-".join(serie.Sample_1.split("-")[:2])
    SampleID_no_slash = SampleID.replace("/", ".")
    dataset_list = [SampleID_no_slash, serie.Target1, serie.Target2, serie.Target3, serie.Target4, serie.Target5, serie.Target6, serie.Target7]
    return "_".join([s for s in dataset_list if s != "nan"])


def main(args):
    log = pd.read_excel(args.log_xlsx).astype(str)
    m = re.search(r'(.*)__.*-Measurement\ (.*)', args.dir)
    slide_or_plateID = m.group(1)
    meas_id = m.group(2)
    selected = log[
            (log.Measurement == meas_id)
            & (log.Automated_PlateID == slide_or_plateID)]
    if selected.shape[0] == 0:
        selected = log[
            (log.Measurement == meas_id)
            & (log.SlideID == slide_or_plateID)
        ]

    assert selected.shape[0] == 1
    line = selected.iloc[0]
    line["OMERO_DATASET"] = generate_omero_dataset(line)
    line["OMERO_project"] = line.Tissue_1
    line["OMERO_internal_group"] = 'Team283'
    line["OMERO_SERVER"] = args.server
    line["PE_folder"] = args.dir
    if line.OMERO_internal_users == "nan":
        line["OMERO_internal_users"] = 'ob5'

    unrenamed_imgs = glob(args.dir + "/A*T0.ome.tiff")
    if len(unrenamed_imgs) > 0:
        all_lines = []
        for p in unrenamed_imgs:
            new_line = line.copy()
            new_name_list = [line.SlideID, line.OMERO_DATASET,
                    "Meas" + meas_id, Path(p).name]
            new_line["filename"] = "_".join(new_name_list).replace("tiff", "tif")
            save_yaml(generate_yaml(p, line), args.dir + "/" + new_line["filename"])
            target_p = "/".join([str(Path(p).parent), new_line.filename])
            shutil.move(p, target_p)
            all_lines.append(new_line)
        df = pd.DataFrame(all_lines)
        df.to_csv("%s.tsv" %args.dir, sep="\t", index=False)
    else:
        print("All renamed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-dir", type=str,
            required=True)

    parser.add_argument("-log_xlsx", type=str,
            required=True)

    parser.add_argument("-server", type=str)

    args = parser.parse_args()

    main(args)
