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
import pandas as pd
import argparse
import logging
import shutil
import os
from tqdm import tqdm
logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", required=True, type=argparse.FileType('r'),
            help="The xlxs log manually generated")
    parser.add_argument("-stitched_root", required=True, type=str,
            help="Directory where the stitched images are stored")
    parser.add_argument("-merged_log", required=True,
            type=str, help="The merged log file")
    parser.add_argument("-rename", required=False,
            type=bool, default=False, help="Rename the tif files")

    args = parser.parse_args()
    move=False
    proj_code = re.search(".*\s(\w+_.*)\sPhenix.*", args.xlsx.name).group(1)
    PE_log = OMERO_preprocess.preprocess_log(args.xlsx.name)
    renamed, failed, not_renamed = \
            OMERO_preprocess.extract_info_from_path(args.stitched_root, proj_code)

    logging.info(
            "\nRenamed: %s\nStitching failed: %s\nNot renamed: %s"
            %(len(renamed), len(failed), len(not_renamed)))

    matched_log, no_match_log = OMERO_preprocess.find_matches_in_PE_and_log(not_renamed, PE_log)
    logging.info(no_match_log)
    if matched_log.shape[0] > 0:
        matched_log = OMERO_preprocess.generate_columns_for_OMERO(matched_log)

        # This is the tmp modification, maybe changed
        matched_log.OMERO_project = matched_log.Tissue_1

        df_for_import = OMERO_preprocess.generate_tsv_for_import(matched_log.copy())
        logging.info(df_for_import)

        if args.rename:
            rename_subset = matched_log[['tif_path', 'new_tif_path']]
            for i in rename_subset.index:
                shutil.move(rename_subset.loc[i].tif_path,
                        rename_subset.loc[i].new_tif_path)

            # Do not generate the import.tsv until all tiffs are renamed
            df_for_import.to_csv("%s_import.tsv" %proj_code, sep="\t", index=False)
    else: # Do note generate the merged log until all unrenamed and matched tiffs are renamed
        matched_log, _ = OMERO_preprocess.find_matches_in_PE_and_log(renamed, PE_log)
        matched_log = OMERO_preprocess.generate_columns_for_OMERO(matched_log)

        # This is the tmp modification, maybe changed
        matched_log.OMERO_project = matched_log.Tissue_1

        tsv_out_name = "%s_%s_merged_log_subset.tsv" %(proj_code, args.merged_log)
        if os.path.exists(tsv_out_name):
            existing_log = pd.read_csv(tsv_out_name, sep="\t")
            matched_log = pd.concat([existing_log, matched_log])
            matched_log = matched_log.drop_duplicates(
                    ["SlideID", "Measurement", "Date", "new_tif_path"]
            )
        matched_log.to_csv(tsv_out_name, index=False, sep="\t")
        print(matched_log)



if __name__ == "__main__":
    main()
