#! /usr/bin/env python3

import fire
import tifffile
from aicsimageio import AICSImage
from Two_step_recon.iterative_deconv.Two_step_dec import Two_step_dec
import numpy as np


def deconvolve_stack(stack, wavelength, NA, pixelsize, finter, highpass=2):
    img = stack.get_image_data("ZYX", T=0, C=0, B=0)
    image = Two_step_dec(img, wavelength, NA, pixelsize, finter)
    image /= image.max() / 2**16
    return image.astype("uint16")


def main(img_p, o, wavelength=470, NA=1.15, finter=2, scene=None):
    stack = AICSImage(img_p)
    try:
        physical_pixel_sizes = stack.physical_pixel_sizes
        pixel_size = physical_pixel_sizes.X * 1000 / finter
    except:
        raise ValueError("No physical pixel size found in metadata")

    if scene is not None:
        stack.set_scene(scene)
        deconvolved_img = deconvolve_stack(stack, wavelength, NA, pixel_size, finter)
        tifffile.imwrite(o, deconvolved_img)
    else:
        for s_ind, s in enumerate(stack.scenes):
            stack.set_scene(s)
            deconvolved_img = deconvolve_stack(
                stack, wavelength, NA, pixel_size, finter
            )
            tifffile.imwrite(f"{o.split('.')[0]}_{s}.tif", deconvolved_img)


if __name__ == "__main__":
    fire.Fire(main)
