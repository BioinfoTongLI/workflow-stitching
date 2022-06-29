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
import pandas as pd
from pathlib import Path
import numpy as np
from glob import glob
import fire


def save_sub_df(sub):
    meas_name = sub.measurement_name.unique()
    sub.to_csv(Path(meas_name[0]).name + ".tsv", index=False, sep="\t")


def main(xlsx, root, PE_index_file_anchor, gap, zmode, export_loc_suffix):
    df = pd.read_excel(xlsx, dtype={"Measurement": str})
    # remove unused cols
    df = df.dropna(how="all", axis=0)

    for ind in df.index:
        row = df.loc[ind]
        if str(row.Automated_PlateID) != "nan":
            tmp_id = row.Automated_PlateID.strip()
        else:
            tmp_id = row.SlideID.strip()
        meas_path = "".join(
            [
                root,
                row.Export_location.replace("\\", "/"),
                export_loc_suffix + "/",
                str(tmp_id),
                "*Measurement ",
                row.Measurement,
                "/",
            ]
        )
        full_p = glob(meas_path + PE_index_file_anchor)
        print(meas_path, full_p)
        # each line of the log file should corresponds to one sinlge measurement in export folder
        assert len(full_p) == 1
        export_loc = full_p[0].replace(PE_index_file_anchor, "")
        df.loc[ind, "measurement_name"] = export_loc.replace(root, "")

        if row.Stitching_Z not in ["max", "none"]:
            df.loc[ind, "Stitching_Z"] = zmode
    # default to user specified gap value if missing
    if "gap" not in df.columns:
        df["gap"] = gap
    df.groupby("measurement_name").apply(save_sub_df)


if __name__ == "__main__":
    fire.Fire(main)
