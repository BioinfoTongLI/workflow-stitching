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
import re
import pandas as pd
import argparse
import logging
import shutil
import os
from tqdm import tqdm
logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)


def main(args):
    if not args.proj_code:
        proj_code = re.search(".*\s(\w+_.*)\sPhenix.*", args.xlsx.name).group(1)
    else:
        proj_code = args.proj_code

    PE_log = OMERO_preprocess.preprocess_log(args.xlsx.name)
    logging.info("Project %s has in total %s measurements" %(proj_code, PE_log.shape[0]))

    logging.info(args.stitched_root)
    all_renamed, all_failed, all_unrenamed = [], [], []
    for root in args.stitched_root:
        renamed, failed, not_renamed = \
                OMERO_preprocess.extract_info_from_path(root, proj_code)
        all_renamed += renamed
        all_failed += failed
        all_unrenamed += not_renamed
        logging.info(
                "\nRenamed: %s\nStitching failed: %s\nNot renamed: %s"
                %(len(renamed), len(failed), len(not_renamed)))

    logging.info(
            "Total counts\nRenamed: %s\nStitching failed: %s\nNot renamed: %s"
            %(len(all_renamed), len(all_failed), len(all_unrenamed)))

    matched_and_unrenamed, no_match_and_unrenamed = OMERO_preprocess.find_matches_in_PE_and_log(all_unrenamed, PE_log)
    logging.info(len(no_match_and_unrenamed))
    if matched_and_unrenamed.shape[0] > 0:
        # Some measurements are not renamed and could be renamed, do it.
        matched_and_unrenamed = OMERO_preprocess.generate_columns_for_OMERO(matched_and_unrenamed)

        # This is the tmp modification, maybe changed
        matched_and_unrenamed.OMERO_project = matched_and_unrenamed.Tissue_1

        logging.info(matched_and_unrenamed[['tif_path', 'new_tif_path']])
        if args.rename:
            rename_subset = matched_and_unrenamed[['tif_path', 'new_tif_path']]
            for i in tqdm(rename_subset.index, "Renaming..."):
                shutil.move(rename_subset.loc[i].tif_path,
                        rename_subset.loc[i].new_tif_path)

            # Do not generate the import.tsv until all tiffs are renamed
            df_for_import = OMERO_preprocess.generate_tsv_for_import(matched_and_unrenamed.copy())
            import_name = "%s_import_%s.tsv"
            i = 0
            while os.path.exists(import_name %(proj_code, i)):
                i += 1
            import_name = import_name %(proj_code, i)

            df_for_import.to_csv(import_name, sep="\t", index=False)
    else:
        # All measurements that can be renamed are renamed. Merged the logs
        matched_and_renamed, no_match_and_renamed = \
                OMERO_preprocess.find_matches_in_PE_and_log(all_renamed, PE_log)
        logging.warning(no_match_and_renamed)
        matched_and_renamed = OMERO_preprocess.generate_columns_for_OMERO(matched_and_renamed)

        # This is the tmp modification, maybe changed
        matched_and_renamed.OMERO_project = matched_and_renamed.Tissue_1

        logging.info(matched_and_renamed.columns)
        tsv_out_name = "%s_merged_log_subset_%s.tsv"
        i = 0
        while os.path.exists(tsv_out_name %(proj_code, i)):
            i += 1
        tsv_out_name = tsv_out_name %(proj_code, i)
        if os.path.exists(tsv_out_name):
            existing_log = pd.read_csv(tsv_out_name, sep="\t")
            matched_and_renamed = pd.concat([existing_log, matched_and_renamed])
            # print(matched_and_renamed.columns)
            logging.info(matched_and_renamed.shape)
            matched_and_renamed.drop_duplicates(
                    # ["SlideID", "Measurement", "Automated_PlateID", "Mag_Bin_Overlap"],
                    # ["new_tif_path"]
                    ignore_index=True, inplace=True
            )
        matched_and_renamed.sort_values("SlideID", inplace=True)
        matched_and_renamed.to_csv(tsv_out_name, sep="\t")
        print(matched_and_renamed)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx", required=True, type=argparse.FileType('r'),
            help="The excel log manually generated by experimenters")
    parser.add_argument("-stitched_root", required=True, type=str, nargs="+",
            help="Directory where the stitched images are stored")
    parser.add_argument("-proj_code", required=False, type=str)
    # parser.add_argument("-rename",
            # action='store_false', help="Rename the tif files")
    parser.add_argument('--rename', dest='rename', action='store_true')
    parser.add_argument('--not_rename', dest='rename', action='store_false')
    parser.set_defaults(feature=False)

    args = parser.parse_args()

    main(args)
