#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8

# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""

"""
import argparse
import pandas as pd
import re


def main(args):
    log_df = pd.read_csv(args.log, sep="\t")
    trace_df = pd.read_csv(args.trace, sep="\t")
    concatenated_lines = []
    for ind in range(trace_df.shape[0]):
        l = trace_df.iloc[ind, :]
        # print(l)
        if "acapella -license /home/acapella/AcapellaLicense.txt" in l.script:
            # print(l.script)
            slide_or_plate = re.search(".*/(.*)__.*", l.script).group(1)
            meas_id = re.search(".*Measurement (.*)\" -s ZProj.*", l.script).group(1)
            selected = log_df[(log_df.Measurement.astype(str) == meas_id) &
                (log_df.SlideID == slide_or_plate)]
            if selected.shape[0] < 1:
                selected = log_df[(log_df.Measurement == meas_id) &
                    (log_df.Automated_PlateID == slide_or_plate)]
            # print(type(selected), type(trace_df.iloc[ind + 1, :]))
            selected[trace_df.columns] = trace_df.iloc[ind + 1].values
            # print(trace_df.iloc[ind + 1, :])
            concatenated_lines.append(selected)
    merged_df = pd.concat(concatenated_lines, axis=0)
    merged_df.to_csv("%s.tsv" %args.out_stem, sep="\t", index=False)


if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument("-out_stem", type=str,
            required=True)

    parser.add_argument("-log", type=str,
            required=True)

    parser.add_argument("-trace", type=str,
            required=True)

    args = parser.parse_args()

    main(args)
