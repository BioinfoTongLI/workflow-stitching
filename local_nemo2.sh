#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#

MOUNT_POINT='/tmp/work/'
TMP_NF_WORK="$MOUNT_POINT"

NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$TMP_NF_WORK NXF_VER=22.04.5 nextflow -trace nextflow.executor run /lustre/scratch126/cellgen/team283/tl10/acapella-stitching/main.nf \
    	-params-file $1 \
	-profile local \
	-entry nemo2 \
	--outdir './' \
	-with-report "report.html"
	#-resume \
