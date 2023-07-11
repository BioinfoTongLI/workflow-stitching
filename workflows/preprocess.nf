#!/usr/bin/env/ nextflow
// Copyright © 2023 Tong LI <tongli.bioinfo@proton.me>

nextflow.enable.dsl=2


process two_step_recon {
    debug true

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'bioinfotongli/preprocessing:two-step-recon':
        'bioinfotongli/preprocessing:two-step-recon'}"
    containerOptions "${workflow.containerEngine == 'singularity' ? '--nv':'--gpus all'}"
    publishDir "${params.out_dir}/deconvolved", mode: 'copy'

    input:
    tuple val(meta), path(folder), val(master_ome_tiff)

    output:
    path("${prefix}_deconvolved*.tif"), emit: recon

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    task.ext.args = task.ext.args ?:''
    """
    two_step_recon.py \
        -o ${prefix}_deconvolved.tif \
        -img_p ${folder}/${master_ome_tiff} \
        ${task.ext.args}
    """
}
