#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Merge xlsx log and metadata extracted from stitched image path.
"""
import OMERO_preprocess
from datetime import datetime
import re
import argparse
import logging
import shutil
from tqdm import tqdm
logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", required=True,
            help="The xlxs log manually generated")
    parser.add_argument("-stitched_root", required=True,
            help="Directory where the stitched images are stored")

    args = parser.parse_args()
    move=False
    proj_code = re.search(".*\s(\w+_.*)\sPhenix.*", args.xlsx).group(1)
    PE_log = OMERO_preprocess.preprocess_log(args.xlsx)
    renamed, failed, not_renamed = \
            OMERO_preprocess.extract_info_from_path(args.stitched_root, proj_code)

    logging.info(
            "\nRenamed: %s\nStitching failed: %s\nNot renamed: %s"
            %(len(renamed), len(failed), len(not_renamed)))
    matched_log, no_match_log = OMERO_preprocess.append_PE_info_to_log(not_renamed, PE_log)
    logging.info(no_match_log)
    if matched_log.shape[0] > 0 and move:
        matched_log = OMERO_preprocess.generate_columns_for_OMERO(matched_log)

        # This is the tmp modification, maybe changed
        matched_log.OMERO_project = matched_log.Tissue_1

        df_for_import = OMERO_preprocess.generate_tsv_for_import(matched_log.copy())
        df_for_import.to_csv("%s_import.tsv" %proj_code, sep="\t", index=False)
        matched_log.to_csv("%s_merged_log_subset.tsv" %proj_code, index=False, sep="\t")

        rename_subset = matched_log[['tif_path', 'new_tif_path']]
        for i in rename_subset.index:
            shutil.move(rename_subset.loc[i].tif_path,
                    rename_subset.loc[i].new_tif_path)


if __name__ == "__main__":
    main()
