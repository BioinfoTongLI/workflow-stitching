#!/bin/bash
#BSUB -o logs/%J.o
#BSUB -e logs/%J.e
#BSUB -M 4000
#BSUB -R "select[mem>=4000] rusage[mem=4000]"
#BSUB -q imaging
#BSUB -n 1

export NXF_ANSI_LOG=false
export NXF_OPTS="-Xms4G -Xmx4G -Dnxf.pool.maxThreads=4000"
export WORKDIR=./work

nextflow run bioinfotongli/workflow-stitching -r 913772155b \
    -profile lsf,singularity \
    -entry PREPROCESS_OME_ZARR_TILES_ASHLAR \
    --manifest ./manifest.csv \
    --is_plate true \
    -c run.config \
    -w $WORKDIR \
    -resume

## clean up on exit 0 - delete this if you want to keep the work dir
status=$?
if [[ $status -eq 0 ]]; then
    rm -r $WORKDIR
fi