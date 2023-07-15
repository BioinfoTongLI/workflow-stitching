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

        # clean any lead/tail spaces
        for c in df.columns:
            if isinstance(row[c], str):
                row[c] = row[c].strip()

        if str(row.Automated_PlateID) != "nan":
            tmp_id = row.Automated_PlateID.strip()
        else:
            tmp_id = row.SlideID.strip()
        meas_path = "".join(
            [
                args.root,
                "/",
                row.Export_location.replace("\\", "/"),
                args.export_loc_suffix + "/",
                str(tmp_id) + "_",
                "*Measurement ",
                row.Measurement,
                "/",
            ]
        )

        # loosely search for both Index.xml (Phenix) and Index.idx.xml (Operetta)
        print(f"Searching for measurement matching: '{meas_path}'")
        full_p = glob(f"{meas_path}/Images/Index*.xml")
        print(f"Index file(s) found: {full_p}")
        if len(full_p) == 0:
            raise SystemExit(f"Index file '{meas_path}/Images/Index*.xml' not found.")
        elif len(full_p) > 1:
            print(f"More than one index file. Will use the first match '{full_p[0]}'.")
        full_p = Path(full_p[0])
        # print(meas_path, full_p)
        # each line of the log file should corresponds to one sinlge measurement in export folder
        # assert len(full_p) == 1
        # export_loc = meas_path # full_p.replace(args.PE_index_file_anchor, "")
        # get the measurement folder's name
        df.loc[ind, "measurement_name"] = full_p.parents[1].stem
        # get the path of the index file within the measurement folder
        df.loc[ind, "index_file"] = full_p.as_posix()

        if row.Stitching_Z not in ["max", "none"]:
            df.loc[ind, "Stitching_Z"] = args.zmode

    if "gap" not in df.columns:
        df["gap"] = args.gap

    df.groupby("measurement_name").apply(save_sub_df)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", type=str, required=True)
    parser.add_argument("-root", type=str, required=True)
    parser.add_argument("-gap", type=str, required=True)
    parser.add_argument("-zmode", type=str, required=True)
    parser.add_argument("-export_loc_suffix", type=str, default="")

    args = parser.parse_args()

    main(args)
