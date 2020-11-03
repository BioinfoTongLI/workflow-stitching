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
    # print(ch_maps)
    # print(img_path)
    # print(ome_ch_names)
    ch_names = [ch_maps[ch] if ch in ch_maps else "Background" for ch in ome_ch_names]
    # print(ch_names)

    z_ind = int(np.floor(pixels.SizeZ/2))
    # print(pixels.SizeZ, z_ind)

    # use default XYZCT
    dim_order = pixels.get_DimensionOrder()
    print(dim_order)
    target_z_indexes = np.arange(pixels.SizeC) * pixels.SizeZ + z_ind

    img = imread(img_path)
    ch_flag = "channels"
    yaml_content = {ch_flag:{}, "greyscale": False, "version": 2}
    default_colors = ["56b4E9", "009E73", "F0E442", "0000FF", "CC79A7", "D55E00", "E69f00"]
    for i, ind in enumerate(target_z_indexes):
        current_setting = {}
        current_setting["active"] = True
        current_setting["color"] = default_colors[i]
        current_setting["label"] = ch_names[i]
        current_setting["end"] = 0
        try:
            plane = img[ind].compute()
            plane = plane[plane != 0]
            win_start, win_end = np.percentile(plane, [1, 99])
            print(win_start, win_end)
            current_setting["end"] = int(win_end)
            current_setting["start"] = int(win_start)
        except:
            current_setting["start"] = 500
            print("Dask image loading error, using default channel contrast setting")

        yaml_content[ch_flag][i + 1] = current_setting
    return yaml_content


def save_yaml(yaml_content, path):
    with open(r'%s.render.yml' %path, 'w') as file:
        documents = yaml.dump(yaml_content, file)
        print(documents)


def generate_omero_dataset(serie, p):
    if str(serie.SectionN) != "1":
        current_section = re.search(".*/A.*_F(\d+)T.*ome.tiff", p).group(1)
    else:
        current_section = "1"

    SampleID = "-".join(serie["Sample_%s" %current_section].split("-")[:2])
    SampleID_no_slash = SampleID.replace("/", ".")
    dataset_list = [SampleID_no_slash, serie.Target1, serie.Target2, serie.Target3, serie.Target4, serie.Target5, serie.Target6, serie.Target7]
    return "_".join([s for s in dataset_list if s != "nan"])


def main(args):
    log = pd.read_excel(args.log_xlsx).astype(str)
    log.dropna(how="all", axis=0, inplace=True)
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

    all_lines = []
    for i in range(selected.shape[0]):
        line = selected.iloc[i]

        raw_export = imread("%s/%s/%s/Images/*.tiff" %(
            args.mount_point, line.Export_location.replace("\\", "/"), args.dir))
        line["Raw_Export_Size(Gb)"] = raw_export.nbytes / 1e9

        line["OMERO_project"] = line.Tissue_1
        line["OMERO_internal_group"] = 'Team283'
        line["OMERO_SERVER"] = args.server
        line["PE_folder"] = args.dir
        if line.OMERO_internal_users == "nan":
            line["OMERO_internal_users"] = 'ob5'

        unrenamed_imgs = glob(args.dir + "/A*T0.ome.tiff")
        for p in unrenamed_imgs:
            new_line = line.copy()
            new_line["OMERO_DATASET"] = \
                generate_omero_dataset(new_line, p)
            new_name_list = [new_line.SlideID,
                    new_line.OMERO_DATASET,
                    "Meas" + meas_id, args.z_mode,
                    Path(p).name]
            new_line["filename"] = "_".join(new_name_list).replace("tiff", "tif")
            save_yaml(generate_yaml(p, new_line), args.dir + "/" + new_line["filename"])
            renamed_p = "/".join([str(Path(p).parent), new_line.filename])
            img = imread(p)
            new_line["original_file_path"] = p
            new_line["renamed_file_path"] = renamed_p
            new_line["Stitched_Size(Gb)"] = img.nbytes / 1e9
            new_line["Stitched_axis_0"] = img.shape[-2]
            new_line["Stitched_axis_1"] = img.shape[-1]
            all_lines.append(new_line)

    df = pd.DataFrame(all_lines)
    df.to_csv("%s.tsv" %args.dir, sep="\t", index=False)



if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-dir", type=str,
            required=True)

    parser.add_argument("-log_xlsx", type=str,
            required=True)

    parser.add_argument("-server", type=str)
    parser.add_argument("-mount_point", type=str)
    parser.add_argument("-z_mode", type=str)

    args = parser.parse_args()

    main(args)
