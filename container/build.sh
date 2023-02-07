#! /bin/sh
#
# build.sh
# Copyright (C) 2022 Tong LI <tongli.bioinfo@protonmail.com>
#
# Distributed under terms of the BSD-3 license.
#


docker build -t ashlar -f Dockerfile.ashlar .
docker build -t ashlar_preprocess -f Dockerfile.ashlar_preprocess .
singularity build /lustre/scratch117/cellgen/team283/imaging_sifs/ashlar_preprocess.sif docker-daemon://ashlar_preprocess:latest
