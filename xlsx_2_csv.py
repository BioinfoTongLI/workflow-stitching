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
    df = df.dropna(axis=0, how="all")
    for ind in df.index:
        row = df.loc[ind]
        if str(row.Automated_PlateID) != "nan":
            tmp_id = row.Automated_PlateID
        else:
            tmp_id = row.SlideID
        line = "".join([args.root, row.Export_location.replace("\\", "/"), "/",
            str(tmp_id),
            "*Measurement ",
            str(row.Measurement), "/",
            args.PE_index_file_anchor])
        full_p = glob(line)
        print(line, full_p)
        assert len(full_p) == 1
        export_loc = full_p[0].replace(args.PE_index_file_anchor, "")
        df.loc[ind, "measurement_name"] = export_loc.replace(args.root, "")
    df.to_csv(Path(args.xlsx).stem + ".tsv", index=False, sep="\t")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", type=str,
            required=True)
    parser.add_argument("-root", type=str,
            required=True)
    parser.add_argument("-PE_index_file_anchor", type=str,
            required=False, default="Images/Index.idx.xml")

    args = parser.parse_args()

    main(args)
