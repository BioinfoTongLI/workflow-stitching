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
PROJ_CODE='TL_SYN'
SERVER="imaging.internal.sanger.ac.uk" #Sanger internal server
#SERVER="omero.sanger.ac.uk" #Sanger external server

MOUNT_POINT='/nfs/team283_imaging/'
LOG_FILE=$MOUNT_POINT'0Misc/stitching_log_files/2021.02.17_iNeurons-3.xlsx'

DATE_WITH_TIME=`date "+%Y%m%d%H%M"`
TRACE_FILE="$MOUNT_POINT/0Misc/stitching_trace/${PROJ_CODE}_trace_${DATE_WITH_TIME}.tsv"
TMP_NF_WORK="$MOUNT_POINT/0Misc/stitching_work"


NXF_OPTS='-Dleveldb.mmap=false' NXF_VER="20.10.0" NXF_WORK=$TMP_NF_WORK LSB_DEFAULTGROUP='team283' nextflow -trace nextflow.executor run /lustre/scratch117/cellgen/team283/tl10/acapella-stitching/main.nf \
	-with-trace $TRACE_FILE \
	--proj_code $PROJ_CODE \
	--stamp $DATE_WITH_TIME \
	--mount_point $MOUNT_POINT \
	--log "$LOG_FILE" \
	--server $SERVER \
	--z_mode $Z_MODE \
	--gap $GAP \
	--trace_file $TRACE_FILE \
	-profile standard,singularity
	#-resume
	#--on_corrected '_corrected' \
