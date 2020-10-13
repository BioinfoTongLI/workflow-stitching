#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#


Z_MODE='none'
PROJ_CODE='KM_LNG'
SERVER="imaging.internal.sanger.ac.uk"
#SERVER="omero.sanger.ac.uk"

MOUNT_POINT='/nfs/team283_imaging/'
ARCHIV_LOCATION=$MOUNT_POINT'0Misc/'
LOG_FILE=$ARCHIV_LOCATION'log_files/2020.08.17 KM_LNG Phenix log RNAscope adult lung controls.xlsx'
DATE_WITH_TIME=`date "+%Y%m%d%H%M"`

NXF_OPTS="-Dleveldb.mmap=false" nextflow run main.nf \
	-with-report $ARCHIV_LOCATION/stitching_report/${PROJ_CODE}_report_${DATE_WITH_TIME}.html \
	--proj_code $PROJ_CODE \
	--stamp $DATE_WITH_TIME \
	--mount_point $MOUNT_POINT \
	--log "$LOG_FILE" \
	--server $SERVER \
	--z_mode $Z_MODE

	#-with-trace $ARCHIV_LOCATION/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv \
