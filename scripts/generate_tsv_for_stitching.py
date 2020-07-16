#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Generate the .tsv file for acapella stitching pipeline
"""
from glob import glob
import csv
import argparse
import logging
import os


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("-in", "--in_dir", required=True,
            default="/nfs/HarmonyExports/KR_C19/",
            help='The directory where Harmony exported data are stored')

    parser.add_argument("-target", "--target_dir", required=True,
            help='Target dir to save the stitched images')

    parser.add_argument("-out", "--out_fname", required=True)
    args = parser.parse_args()

    in_dir = args.in_dir + os.sep + "*/Images/Index.idx.xml"
    rs = glob(in_dir)

    logging.info("Found %s measurements" % len(rs))

    with open(args.out_fname, "w") as csvfile:
        writer = csv.writer(csvfile, delimiter='\t')
        for r in rs:
            row = ["/".join(r.split("/")[:-3]), r.split("/")[-3], args.target_dir]
            writer.writerow(row)
            print(",".join(row))


if __name__ == "__main__":
    main()
