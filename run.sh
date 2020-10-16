#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#


#Z_MODE='none'
Z_MODE='max'
PROJ_CODE='RV_END'
SERVER="imaging.internal.sanger.ac.uk"
#SERVER="omero.sanger.ac.uk"

MOUNT_POINT='/nfs/team283_imaging/'
ARCHIV_LOCATION=$MOUNT_POINT'0Misc/'
LOG_FILE=$ARCHIV_LOCATION'stitching_log_files/RV_END for OMERO 161020.xlsx'
DATE_WITH_TIME=`date "+%Y%m%d%H%M"`

NXF_OPTS='-Dleveldb.mmap=false' NXF_WORK=$ARCHIV_LOCATION'stitching_work' NXF_CONDA_CACHEDIR="~/NXF_conda_cache/" nextflow run main.nf \
	-resume \
	-with-report $ARCHIV_LOCATION/stitching_report/${PROJ_CODE}_report_${DATE_WITH_TIME}.html \
	-with-trace $ARCHIV_LOCATION/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv \
	--proj_code $PROJ_CODE \
	--stamp $DATE_WITH_TIME \
	--mount_point $MOUNT_POINT \
	--log "$LOG_FILE" \
	--server $SERVER \
	--z_mode $Z_MODE
