#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyright © 2023 Tong LI <tongli.bioinfo@proton.me>
#
# Distributed under terms of the MIT license.

"""

"""
import fire
from aicsimageio import AICSImage
from pathlib import Path


def main(master_in: Path, file_out: Path):
    img = AICSImage(master_in)
    print(img)
    img.save(file_out)


if __name__ == "__main__":
    fire.Fire(main)
