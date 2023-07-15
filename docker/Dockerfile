FROM continuumio/miniconda3:4.12.0

RUN apt-get install procps -y

RUN conda install -c conda-forge python==3.11.0 bioformats_jar

RUN python3 -m pip install aicsimageio==4.11.0 scikit-image>=0.18 pandas numpy openpyxl
