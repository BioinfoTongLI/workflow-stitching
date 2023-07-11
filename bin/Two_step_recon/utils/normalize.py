#! /usr/bin/env python

import numpy as np


def normalize(img):
    # k = img.shape[0]
    # img =np.real(img)
    # if k > 1:
    #     for i in range (0,k):
    #         L=(np.max(img[i,:, :]))
    #         img[i,:, :] =  img[i,:, :] - np.min(img[i,:, :])
    #         img[i, :, :] = img[i,:, :]/(np.max(img[i,:, :]))
    # else:
    #     img = img - np.min(img)
    #     img = img/(np.max(img))

    k = img.shape[0]
    img = np.real(img)

    img = img - np.min(img)
    img = img / (np.max(img))

    return img
