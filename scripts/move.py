#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
Move stitched measurements to dest folder
"""
import shutil
import os
import pandas as pd
import argparse
from tqdm import tqdm


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("-in", "--csv_in", type=argparse.FileType("r"),
            required=True)
    parser.add_argument("-out", "--out_dir", type=str,
            required=True)

    args = parser.parse_args()

    csv = pd.read_csv(args.csv_in)

    seps = ["/"] * csv.shape[0]

    srcs = csv.iloc[:, 0] + seps + csv.iloc[:, 1]

    for s in tqdm(srcs):
        if os.path.exists(s):
            # print(s)
            shutil.move(s, args.out_dir)

if __name__ == "__main__":
    main()
