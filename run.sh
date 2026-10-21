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

# --entry: 'ashlar_run', 'phenix_icechunk_stitch' or 'phenix_icechunk_ashlar'
# the manifest master_file of the phenix entries points at each measurement's Harmony Index.xml
nextflow run bioinfotongli/workflow-stitching -r develop \
    -profile lsf,singularity \
    --entry phenix_icechunk_ashlar \
    --manifest ./manifest.csv \
    --out_dir ./output \
    -c run.config \
    -w $WORKDIR \
    -resume

## clean up on exit 0 - delete this if you want to keep the work dir
status=$?
if [[ $status -eq 0 ]]; then
    rm -r $WORKDIR
fi