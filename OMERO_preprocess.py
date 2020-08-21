#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Functions that are useful before omero import
"""
import pandas as pd
import os
import re
import numpy as np


def preprocess_log(xlsx_path):
    PE_log = pd.read_excel(xlsx_path)
    PE_log = PE_log.dropna(axis=0, how="all")
    PE_log.Measurement = PE_log.Measurement.astype(str)
    PE_log.Sample_1 = PE_log.Sample_1.astype(str)
    # PE_log.Automated_PlateID = PE_log.Automated_PlateID
    PE_log.Automated_PlateID = [i.strip() for i in PE_log.Automated_PlateID.astype(str)]
    PE_log.Automated_PlateID = PE_log.Automated_PlateID.replace(["nan", "None"], np.nan)
    PE_log.SlideN = PE_log.SlideN.fillna(0).astype(int)
    PE_log = PE_log.assign(SampleID = lambda x: ["-".join(id_str.split("-")[:2]) for id_str in x.Sample_1])
    return PE_log


def extract_info_from_path(root, project_code):
    renamed = []
    failed = []
    not_renamed = []
    for r, ds, fs in os.walk(root):
        for f in fs:
            if f.endswith(".ome.tif") and f.startswith(project_code):
                renamed.append((r, f))
            elif f.endswith(".ome.tiff") and "tmpcache" in ds:
                failed.append((r, f))
            elif f.endswith(".ome.tiff"):
                not_renamed.append((r, f))
    return renamed, failed, not_renamed


def find_matches_in_PE_and_log(file_list, PE_log):
    matched_log = []
    no_matched_log = []
    for r, f in file_list:
        info_from_path = pd.Series(index=["tif_path", "WellID_PE", "Measurement_PE",
                                  "SlideID_PE", "PlateID_PE", "PE_filename"], dtype=str)
#         new_r = r.replace("HarmonyExports", "0HarmonyExports")

        fname = re.search(r'.*(A\d+_F\d+P\d+T\d+.ome.tif).*', f).group(1)
        WellId = re.search(r'.*A(\d+)_F.*P.*T.*.ome.tif.*', f).group(1)
        measureId = str(re.search(r'.*Measurement (\d+.*)', r).group(1))
        slide_or_plateId = re.search(r'.*/(.*)__20.*', r).group(1)

        info_from_path["tif_path"] = r + "/" + f
        info_from_path["WellID_PE"] = WellId
        info_from_path["Measurement_PE"] = str(measureId)
        info_from_path["PE_filename"] = fname

        current_line = None

        if re.match('^\d+', slide_or_plateId) != None or "multi" in slide_or_plateId:
            info_from_path["PlateID_PE"] = slide_or_plateId
            the_line = PE_log[(PE_log.Automated_PlateID == slide_or_plateId) &
                              (PE_log.Measurement == measureId)]
            if the_line.shape[0] == 1: # it is already unique without wellId
                info_from_path["SlideID_PE"] = the_line.SlideID.values[0]
                current_line = the_line.iloc[0].append(info_from_path, ignore_index=False)
            elif the_line.shape[0] > 1:
                the_line = the_line[the_line.SlideN == int(WellId)] # if multiple slide, use the wellId to identify
                if the_line.shape[0] == 1:
                    info_from_path["SlideID_PE"] = the_line.SlideID.values[0]
                    current_line = the_line.iloc[0].append(info_from_path, ignore_index=False)
                else:
                    no_matched_log.append((r, f))
            else:
                no_matched_log.append((r, f))
        else:
            info_from_path["SlideID_PE"] = slide_or_plateId
            the_line = PE_log[(PE_log.SlideID == slide_or_plateId) &
                              (PE_log.Automated_PlateID.isna()) &
                              (PE_log.Measurement == str(measureId))]
            if the_line.shape[0] == 1:
                current_line = the_line.iloc[0].append(info_from_path, ignore_index=False)
            else:
                no_matched_log.append((r, f))

        if current_line is not None:
            matched_log.append(current_line)
    return pd.DataFrame(matched_log), no_matched_log


def generate_omero_dataset(x):
    ch_names = []
    for i in x.index:
        ch_list = [x.loc[i].SampleID_no_slash, x.loc[i].Target1, x.loc[i].Target2, x.loc[i].Target3, x.loc[i].Target4, x.loc[i].Target5, x.loc[i].Target6, x.loc[i].Target7]
        ch_list_str = [ch for ch in ch_list if isinstance(ch, str)]
        ch_names.append("_".join(ch_list_str))
    return ch_names


def generate_columns_for_OMERO(df):

    # Generate OMERO_DATASET column
    df["SampleID_no_slash"] = [i.replace("/", ".") for i in df.SampleID]
    df = df.assign(OMERO_DATASET=generate_omero_dataset)

    #
    sep_col = pd.Series(["_"]* df.shape[0])
    df["OMERO_fileName"] = df.SlideID_PE + sep_col + df.OMERO_DATASET + sep_col + pd.Series(["Meas"]* sep_col.shape[0]) + df.Measurement_PE + sep_col + df.PE_filename

    del df["SampleID_no_slash"]

#     del df["Renamed_file"]

    df["OMERO_internal_group"] = "Team283"
    # df.OMERO_internal_users = df.OMERO_internal_users.fillna("kr19")

    df = df.assign(dataDir = lambda x: ["/".join(fpath.split("/")[:-1]) + "/" for fpath in x.tif_path])

    df["new_tif_path"] = df.dataDir + df.OMERO_fileName

    del df["dataDir"]

    return df


def generate_image_location_path(df):
    locations = []
    for p in df.new_tif_path:
        new_p = p
        if "/nfs/team283_imaging" not in new_p:
             new_p = new_p.replace("/nfs", "/nfs/team283_imaging")
        locations.append("/".join(new_p.split("/")[:-1]))
    return locations


def generate_tsv_for_import(df_for_import):
    df_for_import = df_for_import.assign(location = generate_image_location_path)

    df_for_import =  df_for_import.assign(filename = lambda x: [s.split("/")[-1] for s in x.new_tif_path])

    df_for_import = df_for_import[["location","filename", "Project", "OMERO_internal_group", "OMERO_internal_users", "OMERO_project", "OMERO_DATASET"]]

    return df_for_import
