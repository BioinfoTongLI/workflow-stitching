#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#


#Z_MODE='none'
Z_MODE='max'
GAP='15000'
PROJ_CODE='Broken_fix'
SERVER="imaging.internal.sanger.ac.uk"
#SERVER="omero.sanger.ac.uk"

MOUNT_POINT='/nfs/team283_imaging/'
ARCHIV_LOCATION=$MOUNT_POINT'0Misc/'
LOG_FILE=$ARCHIV_LOCATION'stitching_log_files/2019.10.16_Only_broken_image.xlsx'
DATE_WITH_TIME=`date "+%Y%m%d%H%M"`
TRACE_FILE="$ARCHIV_LOCATION/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv"
#TMP_NF_WORK='/lustre/scratch117/cellgen/team283/tl10/stitching_work'
TMP_NF_WORK=$HOME'/stitching_work'


NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$TMP_NF_WORK nextflow run main.nf \
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
