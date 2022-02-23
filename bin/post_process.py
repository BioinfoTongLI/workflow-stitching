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
import fire
import pandas as pd
from glob import glob
import re
from pathlib import Path
from dask_image.imread import imread

# from apeer_ometiff_library import omexmlClass
from ome_types import from_xml
import tifffile as tf
import numpy as np
import yaml


def generate_yaml(img_path, meas):
    with tf.TiffFile(img_path) as fh:
        md = from_xml(fh.ome_metadata)
    ch_prob_cols = [ind for ind in meas.index if ind.startswith("Channel")]
    tar_ch_cols = [s.replace("Channel", "Target") for s in ch_prob_cols]
    ch_maps = {
        meas[ch_prob]: meas[tar_ch_cols[i]]
        for i, ch_prob in enumerate(ch_prob_cols)
        if meas[ch_prob] != "nan"
    }

    ome_ch_names = [ch.name for ch in md.images[0].pixels.channels]
    ch_names = [
        str(ch_maps[ch]) if ch in ch_maps else "Background" for ch in ome_ch_names
    ]

    z_ind = int(np.floor(md.images[0].pixels.size_z / 2))

    # use default XYZCT
    dim_order = md.images[0].pixels.dimension_order
    print(dim_order)
    target_z_indexes = (
        np.arange(md.images[0].pixels.size_c) * md.images[0].pixels.size_z + z_ind
    )

    img = imread(img_path)
    ch_flag = "channels"
    yaml_content = {ch_flag: {}, "greyscale": False, "version": 2}
    default_colors = [
        "56b4E9",
        "009E73",
        "F0E442",
        "0000FF",
        "CC79A7",
        "D55E00",
        "E69f00",
    ]
    for i, ind in enumerate(target_z_indexes):
        current_setting = {}
        current_setting["active"] = True
        current_setting["color"] = default_colors[i]
        current_setting["label"] = ch_names[i]
        current_setting["end"] = 1000
        current_setting["start"] = 100

        # try:
        # plane = img[ind].compute()
        # plane = plane[plane != 0]
        # win_start, win_end = np.percentile(plane, [1, 99])
        # print(win_start, win_end)
        # current_setting["end"] = int(win_end)
        # current_setting["start"] = int(win_start)
        # except:
        # print("Dask image loading error, using default channel contrast setting")

        yaml_content[ch_flag][i + 1] = current_setting
    return yaml_content


def save_yaml(yaml_content, path):
    with open(r"%s.render.yml" % path, "w") as file:
        documents = yaml.dump(yaml_content, file)


def generate_omero_dataset(serie, p):
    if str(serie.SectionN) != "1":
        current_section = re.search(".*/.*_F(\d)T.*.tiff", p).group(1)
    else:
        current_section = "1"

    SampleID = "-".join(str(serie["Sample_%s" % str(current_section)]).split("-")[:2])
    SampleID_no_slash = SampleID.replace("/", ".")
    dataset_list = [
        SampleID_no_slash,
        serie.Target1,
        serie.Target2,
        serie.Target3,
        serie.Target4,
        serie.Target5,
        serie.Target6,
        serie.Target7,
    ]
    dataset_list = [str(s) for s in dataset_list]
    return "_".join([s for s in dataset_list if s != "nan"])


def process_one_slide(row, dir_in, mount_point, server):

    img_path_reg = f"{dir_in}/*.ome.tiff"
    img_paths = glob(img_path_reg)
    assert len(img_paths) >= 1

    try:
        raw_export = imread(
            "%s/%s/%s/images/*.tiff"
            % (
                mount_point,
                row.export_location.replace("\\", "/"),
                dir_in.replace("_max", "").replace("_none", ""),
            )
        )
        raw_size = raw_export.nbytes / 1e9
    except:
        # multislide plate, hard to know how large this acquisition is
        raw_size = ""
    row["raw_export_size(gb)"] = raw_size
    row["OMERO_project"] = row.Tissue_1
    row["OMERO_internal_group"] = "Team283"
    row["OMERO_SERVER"] = server
    row["Meas_folder_with_zmode"] = dir_in
    if row.OMERO_internal_users == "nan":
        row["OMERO_internal_users"] = "ob5"

    all_sections = []
    for img_p in img_paths:
        # print(img_p)
        row_section = row.copy()
        row_section["OMERO_DATASET"] = generate_omero_dataset(row, img_p)

        file_prefix = (
            row_section.SlideID
            if row_section.SlideID != "*"
            else row_section.OMERO_project
        )
        new_name_list = [
            file_prefix,
            row_section.OMERO_DATASET,
            "Meas" + row_section.Measurement,
            Path(img_p).name,
        ]
        row_section["filename"] = "_".join(new_name_list).replace("tiff", "tif")

        save_yaml(
            generate_yaml(img_p, row_section), dir_in + "/" + row_section["filename"]
        )

        renamed_p = "/".join([str(Path(img_p).parent), row_section.filename])
        img = imread(img_p)
        row_section["original_file_path"] = img_p
        row_section["renamed_file_path"] = renamed_p
        row_section["Stitched_Size(Gb)"] = img.nbytes / 1e9
        row_section["Stitched_axis_0"] = img.shape[-2]
        row_section["Stitched_axis_1"] = img.shape[-1]
        all_sections.append(row_section)

    return pd.DataFrame(all_sections)


def main(dir_in, log_tsv, server, mount_point):
    log = pd.read_csv(log_tsv, sep="\t", dtype={"Measurement": str})
    all_sections = []
    for i in range(log.shape[0]):
        all_sections.append(process_one_slide(log.iloc[i], dir_in, mount_point, server))
    pd.concat(all_sections).to_csv(f"{dir_in}.tsv", sep="\t", index=False)


if __name__ == "__main__":
    fire.Fire(main)
