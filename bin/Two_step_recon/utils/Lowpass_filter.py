#! /usr/bin/env python
import math
import warnings
import numpy as np
import matlab
import matlab.engine

try:
    import cupy as cp
except ImportError:
    cupy = None

xp = np if cp is None else cp

if xp is not cp:
    warnings.warn("could not import cupy... falling back to numpy & cpu.")
eng = matlab.engine.start_matlab()


def Lowpass_filter(img, FRC):
    if xp is not np:
        img = xp.asarray(img)
    dim = img.ndim
    F = genfilter(max(img.shape), 1, FRC)
    if dim == 3:
        [z, x, y] = img.shape
        L = F.shape[1]
        F = matlab.double(F.tolist())
        Fresized = eng.imresize(F, x / L, "bilinear")
        Fresized = xp.array(Fresized)
        Fresized = Fresized / xp.max(Fresized)
        imgfiltered = xp.zeros((z, x, y))
        for i in range(0, img.shape[0], 1):
            img[i, :, :] = img[i, :, :]
            imgfiltered[i, :, :] = abs(
                xp.fft.ifftn(xp.fft.fftshift(xp.fft.fftn(img[i, :, :])) * Fresized)
            )
    else:
        [x, y] = img.shape
        L = F.shape[0]
        print(type(F))
        F = matlab.double(F.tolist())
        Fresized = eng.imresize(F, x / L, "bilinear")
        Fresized = xp.array(Fresized)
        Fresized = Fresized / xp.max(Fresized)
        imgfiltered = abs(xp.ifftn(xp.fftshift(xp.fftn(img)) * Fresized))
    if xp is not np:
        imgfiltered = xp.asnumpy(imgfiltered)
    return imgfiltered


def genfilter(imgsz, pixelsize, resolution):
    [X, Y] = xp.meshgrid(
        xp.arange(-imgsz / 2, imgsz / 2), xp.arange(-imgsz / 2, imgsz / 2)
    )
    Zo = xp.sqrt(X**2 + Y**2)
    scale = imgsz * pixelsize
    k_r = Zo / scale
    T = resolution / 2 / 1.4
    beta = 1
    rcfilter = 1 / 2 * (1 + xp.cos(math.pi * T / beta * (k_r - (1 - beta) / 2 / T)))
    mask1 = k_r < (1 - beta) / 2 / T
    rcfilter[mask1] = 1
    mask2 = k_r > (1 + beta) / 2 / T
    rcfilter[mask2] = 0
    return rcfilter
