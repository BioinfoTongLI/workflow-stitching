#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Move ymls to image folders
"""
import argparse
import pandas as pd
import shutil


def main(args):
    df = pd.read_csv(args.tsv, sep="\t")
    for idx in df.index:
        row = df.loc[idx]
        for yml in args.ymls:
            if yml.startswith(row.loc["filename"]):
                shutil.copyfile(yml, row.loc["location"] + "/" + yml)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-tsv", type=str,
            required=True)

    parser.add_argument("-ymls", type=str, nargs="+",
            required=True)
    args = parser.parse_args()

    main(args)
