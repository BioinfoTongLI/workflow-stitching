#! /bin/sh
#
# run.sh
# Copyright (C) 2023 Tong LI <tongli.bioinfo@proton.me>
#
# Distributed under terms of the BSD-3 license.
#


NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK='/tmp/work' LSB_DEFAULTGROUP='team283' /lustre/scratch117/cellgen/team283/tl10/nextflow/nextflow -trace nextflow.executor run /lustre/scratch117/cellgen/team283/tl10/acapella-stitching/main.nf \
	-params-file $1 \
	-profile local \
	-entry nemo \
	-with-report "report.html" \
	-resume
