#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Convert xlsx to csv file
"""
import argparse
import pandas as pd
from pathlib import Path
import numpy as np
from glob import glob


def save_sub_df(sub):
    meas_name = sub.measurement_name.unique()
    sub.to_csv(Path(meas_name[0]).name + ".tsv", index=False, sep="\t")


def main(args):
    df = pd.read_excel(args.xlsx, dtype={"Measurement": str})
    df = df.dropna(how="all", axis=0)
    for ind in df.index:
        row = df.loc[ind]
        if str(row.Automated_PlateID) != "nan":
            tmp_id = row.Automated_PlateID.strip()
        else:
            tmp_id = row.SlideID.strip()
        meas_path = "".join([args.root, row.Export_location.replace("\\", "/"), args.export_loc_suffix + "/",
            str(tmp_id),
            "*Measurement ",
            row.Measurement, "/"])
        full_p = glob(meas_path + args.PE_index_file_anchor)
        print(meas_path, full_p)
        # each line of the log file should corresponds to one sinlge measurement in export folder
        assert len(full_p) == 1
        export_loc = full_p[0].replace(args.PE_index_file_anchor, "")
        df.loc[ind, "measurement_name"] = export_loc.replace(args.root, "")

        if row.Stitching_Z not in ["max", "none"]:
            df.loc[ind, "Stitching_Z"] = args.zmode
    if "gap" not in df.columns:
        df["gap"] = args.gap
    df.groupby("measurement_name").apply(save_sub_df)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", type=str,
            required=True)
    parser.add_argument("-root", type=str,
            required=True)
    parser.add_argument("-PE_index_file_anchor", type=str,
            required=False, default="Images/Index.xml")
    parser.add_argument("-gap", type=str,
            required=True)
    parser.add_argument("-zmode", type=str,
            required=True)
    parser.add_argument("-export_loc_suffix", type=str, default="")

    args = parser.parse_args()

    main(args)
