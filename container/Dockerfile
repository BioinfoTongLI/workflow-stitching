FROM python:3.9-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN python3 -m pip install --upgrade pip --no-cache-dir

RUN pip3 install fire dask_image scikit-image>=0.18 openpyxl tifffile pandas numpy ome-types ome-model
