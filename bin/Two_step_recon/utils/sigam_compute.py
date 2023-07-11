#! /usr/bin/env python

import warnings
import numpy as np

try:
    import cupy as cp
except ImportError:
    cupy = None
xp = np if cp is None else cp

if xp is not cp:
    warnings.warn("could not import cupy... falling back to numpy & cpu.")


def sigam_compute(pixelsize, FRC):
    dim = pixelsize.ndim
    if dim == 1:
        sigma = [FRC / pixelsize, FRC / pixelsize]
    elif dim == 2:
        sigma = [FRC[0] / pixelsize[0], FRC[1] / pixelsize[1]]
    elif dim == 3:
        sigma = [FRC[0] / pixelsize[0], FRC[1] / pixelsize[1], FRC[2] / pixelsize[2]]
    return sigma
