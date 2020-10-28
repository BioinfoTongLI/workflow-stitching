#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#


#Z_MODE='none'
Z_MODE='max'
GAP='4000'
PROJ_CODE='RV_GON'
SERVER="imaging.internal.sanger.ac.uk"
#SERVER="omero.sanger.ac.uk"
MY_LUSTRE="/lustre/scratch117/cellgen/team283/tl10/"

MOUNT_POINT='/nfs/team283_imaging/'
ARCHIV_LOCATION=$MOUNT_POINT'0Misc/'
LOG_FILE=$ARCHIV_LOCATION'stitching_log_files/RV_GON_00F6.xlsx'
DATE_WITH_TIME=`date "+%Y%m%d%H%M"`
TRACE_FILE="$ARCHIV_LOCATION/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv"
TMP_NF_WORK=$MY_LUSTRE'stitching_work'
#TMP_NF_WORK=$HOME'/stitching_work'


NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$TMP_NF_WORK LSB_DEFAULTGROUP='team283' nextflow run $MY_LUSTRE/acapella-stitching/main.nf \
	-with-trace $TRACE_FILE \
	--proj_code $PROJ_CODE \
	--stamp $DATE_WITH_TIME \
	--mount_point $MOUNT_POINT \
	--log "$LOG_FILE" \
	--server $SERVER \
	--z_mode $Z_MODE \
	--gap $GAP \
	--trace_file $TRACE_FILE \
	-profile 'lsf' \
	-resume
