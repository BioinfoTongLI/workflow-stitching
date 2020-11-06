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


def main(args):
    df = pd.read_excel(args.xlsx)
    df = df.dropna(how="all", axis=0)
    for ind in df.index:
        row = df.loc[ind]
        if str(row.Automated_PlateID) != "nan":
            tmp_id = row.Automated_PlateID.strip()
        else:
            tmp_id = row.SlideID.strip()
        meas_path = "".join([args.root, row.Export_location.replace("\\", "/"), "/",
            str(tmp_id),
            "*Measurement ",
            str(row.Measurement), "/"])
        full_p = glob(meas_path + args.PE_index_file_anchor)
        print(meas_path, full_p)
        assert len(full_p) == 1
        export_loc = full_p[0].replace(args.PE_index_file_anchor, "")
        df.loc[ind, "measurement_name"] = export_loc.replace(args.root, "")
    if "gap" not in df.columns:
        df["gap"] = args.gap
    df.to_csv(Path(args.xlsx).stem + ".tsv", index=False, sep="\t")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", type=str,
            required=True)
    parser.add_argument("-root", type=str,
            required=True)
    parser.add_argument("-PE_index_file_anchor", type=str,
            required=False, default="Images/Index.idx.xml")
    parser.add_argument("-gap", type=str,
            required=True)

    args = parser.parse_args()

    main(args)
