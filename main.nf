#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/stitching_log_files/2022.05.04_iNeurons.xlsx'
params.proj_code = "TL_SYN"

params.out_dir = params.mount_point + "0HarmonyStitched/" // default location, don't change
params.server = "omero.sanger.ac.uk" // or "imaging.internal.sanger.ac.uk" deprecated

params.z_mode = 'max' // none or max
params.stamp = '' // time stamp of execution
params.gap = 4000 // maximum distance between tiles
params.fields = 'ALL' // selection of field of views
params.on_corrected = "" // "" or "_corrected" for flat-field corrected tiles
params.index_file = "Images/Index.xml"

container_path = "gitlab-registry.internal.sanger.ac.uk/tl10/acapella-stitching:latest"
sif_folder = "/lustre/scratch117/cellgen/team283/imaging_sifs/"
debug = true
params.is_slide = true

/*
    Convert the xlsx file to .tsv that is nextflow friendly
    some sanity check is also performed here
*/
process xlsx_to_tsv {
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"

    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':' + params.mount_point + ':ro' :
        '-v ' + params.mount_point + ':' + params.mount_point + ':ro'}"

    input:
    file log_file
    val mount_point
    val gap
    val z_mode
    val on_corrected
    val PE_index_file_anchor

    output:
    file "*.tsv"

    script:
    """
    xlsx_2_tsv.py --xlsx ${log_file} --root ${mount_point} --gap ${gap} --zmode ${z_mode} --export_loc_suffix "${on_corrected}" --PE_index_file_anchor ${PE_index_file_anchor}
    """
}


/*
    Acapella stitching
*/
process stitch {
    tag "$meas_folder"
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/acapella-1.1.8.sif':
        'acapella-in-docker'}"
    containerOptions "-B ${params.mount_point}:/data_in/:ro,/tmp/:/tmp/acapella/:rw"
    storeDir params.out_dir + "/" + params.proj_code + params.on_corrected

    memory '60 GB'

    input:
    tuple val(meas), val(z_mode), val(gap)
    val fields
    val index_file

    output:
    tuple val(base), path(meas_folder)

    script:
    base = file(meas).getName()
    meas_folder = "${base}_${z_mode}"
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/${index_file}" -s OutputDir="${meas_folder}" -s ZProjection="${z_mode}" -s OutputFormat=tiff -s Silent=false -s Wells="ALL" -s Fields="${fields}" -s Channels="ALL" -s Planes="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


/*
    Generate rendering.yaml for each image and update the tsv for OMERO import
*/
process post_process {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':' + params.mount_point + ':ro' :
        '-v ' + params.mount_point + ':' + params.mount_point + ':ro'}"

    errorStrategy "retry"

    storeDir params.mount_point + '0Misc/stitching_single_tsvs'
    /*publishDir params.mount_point + '0Misc/stitching_single_tsvs', mode:"copy"*/

    input:
    tuple val(meas), path(meas_folder), path(tsv)
    val server
    val mount_point

    output:
    path "${meas_folder}.tsv"

    script:
    """
    post_process.py --dir_in $meas_folder --log_tsv $tsv --server ${server} --mount_point ${mount_point}
    """
}


/*
    Rename the files to be biologically-relevant
*/
process rename {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':' + params.mount_point + ':rw' :
        '-v ' + params.mount_point + ':' + params.mount_point + ':rw'}"

    publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"

    input:
    path tsvs
    val out_dir
    val proj_code
    val stamp
    val mount_point
    val on_corrected

    output:
    path "${proj_code}*${stamp}.tsv"

    script:
    """
    rename.py $tsvs --export_dir "${out_dir}" --project_code "${proj_code}" --stamp "${stamp}" --mount_point "${mount_point}" --corrected "${on_corrected}"
    """
}


process Generate_companion_ome {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "-B ${params.mount_point}"
    /*publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"*/

    input:
    tuple val(base), path(meas_folder)

    /*output:*/
    /*path "*.companion.ome"*/

    script:
    """
    generate_companion_ome.py --images_path ${meas_folder}
    cp *.companion.ome ${meas_folder}
    """
}

/*
    [Optional, so errorStrategy = "ignore"]
    Append stitching benchmark from nextflow.trace into the tsv log
*/
/*params.trace_file = ''*/

/*trace_file_p = Channel.fromPath(params.trace_file)*/

/*process combine {*/
    /*echo true*/
    /*errorStrategy "ignore"*/
    /*conda baseDir + '/conda_env.yaml'*/
    /*publishDir params.mount_point +"0Misc/stitching_merged_log", mode:"copy"*/

    /*input:*/
    /*path log_p from tsv_for_import*/
    /*path trace from trace_file_p*/

    /*output:*/
    /*path "${params.proj_code}_merge_${params.stamp}.tsv"*/

    /*script:*/
    /*"""*/
    /*python ${baseDir}/log_trace_combine.py -log $log_p -trace ${trace} -out_stem ${params.proj_code}_merge_${params.stamp}*/
    /*"""*/
/*}*/

workflow {
    xlsx_to_tsv(channel.fromPath(params.log, checkIfExists: true),
        params.mount_point, params.gap, params.z_mode,
        params.on_corrected, params.index_file)
    /*
        Put parameter channel for stitching
    */
    tsvs_with_names = xlsx_to_tsv.out
        .flatten()
        .map{it -> [it.baseName, it]}
    /*tsvs_with_names.view()*/


    stitching_features = xlsx_to_tsv.out
        .flatten()
        .splitCsv(header:true, sep:"\t")
        .map{it -> [it.measurement_name, it.Stitching_Z, it.gap]}
        .groupTuple()
        .map{it -> [it[0], it[1][0], it[2][0]]}
    /*stitching_features.view()*/

    stitch(stitching_features, params.fields, params.index_file)
    post_process(stitch.out.join(tsvs_with_names), params.server, params.mount_point)
    if (params.is_slide) {
        rename(post_process.out.collect(),
            params.out_dir, params.proj_code, params.stamp,
            params.mount_point, params.on_corrected)
    } else {
        Generate_companion_ome(stitch.out)
    }
}
