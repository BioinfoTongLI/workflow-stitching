#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Take the newest duplicates in a tsv file
"""
import argparse
import pandas as pd


def main(args):
    print(args.tsv_in)
    df = pd.read_csv(args.tsv_in, sep="\t")
    df["Date"] = pd.to_datetime(df.Date)
    df.sort_values(by='Date', inplace=True, ascending=False)
    print(df.Date)
    print(df.shape)
    df.drop_duplicates("filename", inplace=True)
    print(df.Date)
    print(df.shape)
    df.to_csv("/nfs/team283_imaging/KR_C19/playground_tong/KR_C19_import_202011161715_final_duplicates_removed.tsv", sep="\t", index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-tsv_in", type=str,
            default="/nfs/team283_imaging/KR_C19/playground_tong/KR_C19_import_202011161715_final_with_all_images.tsv" )

    args = parser.parse_args()

    main(args)
