#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2020 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.

"""
A simple script to rendering setting
"""
import argparse
import yaml


def main(args):
    for yml in args.yamls_in:
        # print(yml)
        with open(yml) as f:
            list_doc = yaml.load(f)

        for ch in list_doc["channels"]:
            list_doc["channels"][ch]["start"] = 100
            list_doc["channels"][ch]["end"] = 1000

        # print(type(list_doc))
        with open(yml, "w") as f:
            yaml.dump(list_doc, f)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-yamls_in", type=str, nargs="+",
            required=True)

    args = parser.parse_args()

    main(args)
