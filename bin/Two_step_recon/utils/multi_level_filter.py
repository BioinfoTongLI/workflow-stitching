#! /usr/bin/env python
from Two_step_recon.utils.Lowpass_filter import Lowpass_filter
from Two_step_recon.utils.normalize import normalize
from Two_step_recon.utils.background_estimation import background_estimation
from matplotlib import pyplot as plt


def multi_level_filter(img, lowpass, highpass):
    img = Lowpass_filter(img, lowpass)
    img = normalize(img)
    back = background_estimation(img / highpass)
    img = img - back
    img[img < 0] = 0
    img = normalize(img)
    return img
