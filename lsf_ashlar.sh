#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#

#PROJ_CODE=$1
EXCEL_NAME=$2
Z_MODE=$3 # none or max
SERVER=$4 # imaging.internal.sanger.ac.uk OR omero.sanger.ac.uk

MOUNT_POINT='/nfs/team283_imaging/0Misc/'
LOG_FILE=$MOUNT_POINT'0Misc/stitching_log_files/'$EXCEL_NAME

DATE_WITH_TIME=`date "+%Y%m%d%H%M"`
TRACE_FILE="$MOUNT_POINT/0Misc/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv"
TMP_NF_WORK="$MOUNT_POINT/0ashlar_stitching_work"
IMPORT_FILE="$MOUNT_POINT/0Misc/stitching_tsv_for_import/${PROJ_CODE}_import_${DATE_WITH_TIME}.tsv"


NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$TMP_NF_WORK LSB_DEFAULTGROUP='team283' /lustre/scratch126/cellgen/team283/tl10/nextflow/nextflow -trace nextflow.executor run /lustre/scratch126/cellgen/team283/tl10/acapella-stitching/main.nf \
	-params-file $1 \
	-entry nemo \
	-profile lsf \
	-resume
	#-with-trace $TRACE_FILE \
	#--proj_code $PROJ_CODE \
	#--stamp $DATE_WITH_TIME \
	#--mount_point $MOUNT_POINT \
	#--log "$LOG_FILE" \
	#--server $SERVER \
	#--z_mode $Z_MODE \
	#--trace_file $TRACE_FILE \
	#--on_corrected '_corrected' \

#if [[ -n $5 ]]; then
	#/nfs/team283/imaging_pipeline/pipeline-import.git/run.sh ${IMPORT_FILE} ${PROJ_CODE} $5
#else
	#echo "No server specified, skipping upload"
#fi
