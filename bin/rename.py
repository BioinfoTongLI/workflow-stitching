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
import fire
import pandas as pd
from pathlib import Path
from datetime import datetime
import shutil


def main(*tsvs, export_dir, project_code, stamp, corrected, mount_point):
    df = pd.concat([pd.read_csv(tsv, sep="\t") for tsv in tsvs])
    df["location"] = export_dir + project_code + "/" + df.Meas_folder_with_zmode
    root_fpath = f"{mount_point}/0HarmonyStitched/{project_code}{corrected}/"
    print(root_fpath)

    for i in range(df.shape[0]):
        line = df.iloc[i]
        assert Path(root_fpath + line.original_file_path).exists()

    # unrenmaed = []
    for i in range(df.shape[0]):
        line = df.iloc[i]
        target_name = root_fpath + line.renamed_file_path
        try:
            shutil.move(root_fpath + line.original_file_path, target_name)
        except:
            print(target_name)
            unrenmaed.append(line)

    # unrenmaed_df = pd.concat(unrenmaed, axis=1).T
    # unrenamed_file_name = "%s_unrenamed_%s.tsv"\
    # %(args.project_code, args.stamp)
    # unrenmaed_df.to_csv(unrenamed_file_name, sep="\t", index=False)

    df.to_csv(f"{project_code}_import_{stamp}.tsv", sep="\t", index=False)


if __name__ == "__main__":
    fire.Fire(main)
