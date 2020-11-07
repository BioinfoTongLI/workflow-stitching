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
import shutil


def main(args):
    df = pd.concat([pd.read_csv(tsv, sep="\t") for tsv in args.tsvs])
    df["location"] = args.export_dir + args.project_code + "/" +  df.PE_folder
    for i in range(df.shape[0]):
        line = df.iloc[i]
        root_fpath = "%s/0HarmonyStitched/%s/" %(args.mount_point, args.project_code)
        try:
            shutil.move(root_fpath + line.original_file_path,
                    root_fpath + line.renamed_file_path)
        except:
            pass
        assert Path(root_fpath + line.renamed_file_path).exists()
    import_name = "%s_import_%s.tsv"\
            %(args.project_code, args.stamp)
    df.to_csv(import_name, sep="\t", index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-tsvs", type=str, nargs="+",
            required=True)
    parser.add_argument("-export_dir", type=str, required=True)
    parser.add_argument("-project_code", type=str, required=True)
    parser.add_argument("-stamp", type=str, required=True)
    parser.add_argument("-mount_point", type=str)

    args = parser.parse_args()

    main(args)
