#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Take split tsvs and extract import.tsv for OMERO import
"""
import argparse
import pandas as pd
from pathlib import Path
from datetime import datetime


def main(args):
    df = pd.concat([pd.read_csv(tsv, sep="\t") for tsv in args.tsvs])
    df["location"] = args.export_dir + args.project_code + "/" +  df.PE_folder
    # import_df = df[["location", "filename", "Project", "OMERO_internal_group", "OMERO_internal_users", "OMERO_project", "OMERO_DATASET", "OMERO_SERVER"]]
    for i in range(0, df.shape[0]):
        line = df.iloc[i]
        tmp_p = "/".join([str(line.location), str(df.iloc[i].filename)])
        assert Path(tmp_p).exists()
    import_name = "%s_import_%s.tsv"\
            %(args.project_code, datetime.today().strftime('%Y%m%d%H%M'))
    df.to_csv(import_name, sep="\t", index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-tsvs", type=str, nargs="+",
            required=True)
    parser.add_argument("-export_dir", type=str, required=True)
    parser.add_argument("-project_code", type=str, required=True)

    args = parser.parse_args()

    main(args)
