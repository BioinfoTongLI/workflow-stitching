#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Take an exiting log file and add PE meatdata to it
"""
import argparse
import OMERO_preprocess
import re
import logging
import shutil
import os
logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)


def main(args):
    if not args.proj_code:
        proj_code = re.search(".*\s(\w+_.*)\sPhenix.*", args.xlsx.name).group(1)
    else:
        proj_code = args.proj_code

    PE_log = OMERO_preprocess.preprocess_log(args.xlsx.name)
    logging.info("The log file of  %s has in total %s measurements" %(proj_code, PE_log.shape[0]))

    all_renamed, all_failed, all_unrenamed = [], [], []
    renamed, failed, not_renamed = \
            OMERO_preprocess.extract_info_from_path(args.stitched_root, proj_code)
    all_renamed += renamed
    all_failed += failed
    all_unrenamed += not_renamed

    logging.info(
            "Total counts\nRenamed: %s\nStitching failed: %s\nNot renamed: %s"
            %(len(all_renamed), len(all_failed), len(all_unrenamed)))

    matched_and_unrenamed, no_match_and_unrenamed = \
            OMERO_preprocess.find_matches_in_PE_and_log(all_renamed, PE_log)
    # All measurements that can be renamed are renamed. Merged the logs
    matched_and_renamed, no_match_and_renamed = \
            OMERO_preprocess.find_matches_in_PE_and_log(all_renamed, PE_log)
    # logging.warning(matched_and_renamed)
    matched_and_renamed = OMERO_preprocess.generate_columns_for_OMERO(matched_and_renamed)


    # This is the tmp modification, maybe changed
    matched_and_renamed.OMERO_project = matched_and_renamed.Tissue_1

    tsv_out_name = "%s_merged_log_subset_%s.tsv"
    i = 0
    while os.path.exists(tsv_out_name %(proj_code, i)):
        i += 1
    tsv_out_name = tsv_out_name %(proj_code, i)
    # if os.path.exists(tsv_out_name):
        # existing_log = pd.read_csv(tsv_out_name, sep="\t")
        # matched_and_renamed = pd.concat([existing_log, matched_and_renamed])
        # # print(matched_and_renamed.columns)
        # logging.info(matched_and_renamed.shape)
        # matched_and_renamed.drop_duplicates(
                # # ["SlideID", "Measurement", "Automated_PlateID", "Mag_Bin_Overlap"],
                # # ["new_tif_path"]
                # ignore_index=True, inplace=True
        # )

    df_for_import = OMERO_preprocess.generate_tsv_for_import(
            matched_and_renamed.copy())
    import_name = "%s_import_%s.tsv"
    i = 0
    while os.path.exists(import_name %(proj_code, i)):
        i += 1
    import_name = import_name %(proj_code, i)

    df_for_import.to_csv(import_name, sep="\t", index=False)
    matched_and_renamed.sort_values("SlideID", inplace=True)
    matched_and_renamed.to_csv(tsv_out_name, sep="\t", index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-xlsx",
            # required=True,
            type=argparse.FileType('r'),
            help="The excel log manually generated by experimenters",
            default='/nfs/TL_SYN/log_files/2020-08-11-dataTransfer_Alik.xlsx'
            )
    parser.add_argument("-stitched_root",
            # required=True,
            type=str, nargs="+",
            help="Directory where the stitched images are stored",
            default='/nfs/team283_imaging/0HarmonyStitched/KR_C19/'
            )
    parser.add_argument("-proj_code",
            required=False,
            type=str,
            default='KR_C19')
    # parser.add_argument("-rename",
            # action='store_false', help="Rename the tif files")
    parser.set_defaults(feature=False)

    args = parser.parse_args()

    main(args)