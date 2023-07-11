#! /usr/bin/env python
from matplotlib import pyplot as plt
from Two_step_recon.utils.upsample import spatial_upsample, fourier_upsample
from skimage import io
from Two_step_recon.utils.background_estimation import background_estimation
from Two_step_recon.iterative_deconv.iterative_deconv import iterative_deconv
from Two_step_recon.iterative_deconv.kernel import Gauss
from Two_step_recon.utils.normalize import normalize
from Two_step_recon.utils.percennorm import percennorm
import numpy as np


def Two_step_dec(img, wavelength, NA, pixelsize, finter, highpass=2):
    NA = NA / 2
    resolution = 0.5 * wavelength / NA
    stack = np.array(img, dtype="float32")
    imgdecon2full = np.zeros((stack.shape[0], stack.shape[1] * 2, stack.shape[2] * 2))
    z = stack.shape[0]
    sigma1 = resolution / pixelsize
    kernel1 = Gauss(sigma1)
    sigma2 = (resolution / 1.3) / (pixelsize)
    kernel2 = Gauss(sigma2)
    for i in range(0, z):
        stack[i, :, :] = percennorm(stack[i, :, :])
        if finter == 1 or finter == 0:
            image = image
        else:
            image = fourier_upsample(stack[i, :, :], finter)
        image = percennorm(image)
        back = background_estimation(image / highpass, 1, 5, "db7")
        image = image - back
        image[image < 0] = 0
        # image = iterative_deconv(image, kernel1, 9, rule=1)
        # sigma = (resolution / 1.3) / (pixelsize)
        # image = iterative_deconv(image,  kernel2 , 6, rule=1)
        imagedecon1 = iterative_deconv(image, kernel1, 10, rule=1)
        imagedecon2 = iterative_deconv(imagedecon1, kernel2, 7, rule=1)
        imgdecon2full[i, :, :] = imagedecon2 * np.max(stack[i, :, :])
        # image = np.array(imgdecon2full[i, :, :], dtype='float32')
        # io.imsave('F:/Two_Step_py_main _2023_4_25/保存图/test%d.tiff' % (i + 1), image.astype(stack.dtype))
    return imgdecon2full
