#! /usr/bin/env python
import numpy as np

# import matlab
from matplotlib import mlab


# import matlab.engine
# eng=matlab.engine.start_matlab()
def percennorm(img, miper=0, maper=100):
    img = np.array(img, dtype="float32")
    # img  = matlab.double(img .tolist())
    datamin = np.percentile(img, miper, interpolation="midpoint")
    datamax = np.percentile(img, maper, interpolation="midpoint")
    output = (img - datamin) / (datamax - datamin)
    output[output > 1] = 1
    output[output < 0] = 0

    return output
