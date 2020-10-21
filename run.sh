#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#


#Z_MODE='none'
Z_MODE='max'
GAP='2000'
PROJ_CODE='test'
SERVER="imaging.internal.sanger.ac.uk"
#SERVER="omero.sanger.ac.uk"

MOUNT_POINT='/nfs/team283_imaging/'
ARCHIV_LOCATION=$MOUNT_POINT'0Misc/'
LOG_FILE=$ARCHIV_LOCATION'stitching_log_files/testset.xlsx'
DATE_WITH_TIME=`date "+%Y%m%d%H%M"`
TRACE_FILE="$ARCHIV_LOCATION/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv"
TMP_NF_WORK='/lustre/scratch117/cellgen/team283/tl10/stitching_work'


NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$TMP_NF_WORK nextflow run main.nf \
	-with-report $ARCHIV_LOCATION/stitching_report/${PROJ_CODE}_report_${DATE_WITH_TIME}.html \
	-with-trace $TRACE_FILE \
	--proj_code $PROJ_CODE \
	--stamp $DATE_WITH_TIME \
	--mount_point $MOUNT_POINT \
	--log "$LOG_FILE" \
	--server $SERVER \
	--z_mode $Z_MODE \
	--gap $GAP \
	--trace_file $TRACE_FILE \
	-resume
