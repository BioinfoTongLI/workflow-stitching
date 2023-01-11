#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#

PROJ_CODE=$1
TSV_NAME=$2
Z_MODE=$3 # none or max
SERVER=$4 # imaging.internal.sanger.ac.uk OR omero.sanger.ac.uk

MOUNT_POINT='/nfs/team283_imaging/'
LOG_FILE=$MOUNT_POINT'0Misc/stitching_log_files/'$2

DATE_WITH_TIME=`date "+%Y%m%d%H%M"`
TRACE_FILE="$MOUNT_POINT/0Misc/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv"
TMP_NF_WORK="$MOUNT_POINT/0Misc/stitching_work"
IMPORT_FILE="$MOUNT_POINT/0Misc/stitching_tsv_for_import/${PROJ_CODE}_import_${DATE_WITH_TIME}.tsv"


NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$TMP_NF_WORK LSB_DEFAULTGROUP='team283' /lustre/scratch117/cellgen/team283/tl10/nextflow/nextflow -trace nextflow.executor run /lustre/scratch117/cellgen/team283/tl10/acapella-stitching/main.nf \
	-params-file $1 \
	-profile local \
	-entry ashlar \
	-resume
