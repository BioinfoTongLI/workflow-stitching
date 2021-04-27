#!/usr/bin/env nextflow

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/stitching_log_files/KR_C19_exported_20201028.xlsx'
params.proj_code = "KR_C19"

params.out_dir = params.mount_point + "0HarmonyStitched/" // default location, don't change
params.server = "omero.sanger.ac.uk" // or "imaging.internal.sanger.ac.uk" deprecated

params.z_mode = 'none' // or max
params.stamp = '' // time stamp of execution
params.gap = 4000 // maximum distance between tiles
params.fields = 'ALL' // selection of field of views
params.on_corrected = "" // or "_corrected" for flat-field corrected tiles

/*
    Convert the xlsx file to .tsv that is nextflow friendly
    some sanity check is also performed here
*/
process xlsx_to_tsv {
    /*echo true*/
    cache "lenient"
    container "/lustre/scratch117/cellgen/team283/tl10/sifs/stitching_processing.sif"
    containerOptions "-B ${baseDir}:/codes,${params.mount_point}"

    output:
    path "*.tsv" into tsvs_for_stitching, tsv_for_post

    script:
    """
    python /codes/xlsx_2_tsv.py -xlsx "$params.log" -root $params.mount_point -gap ${params.gap} -zmode ${params.z_mode} -export_loc_suffix "${params.on_corrected}"
    """
}


/*
    Put parameter channel for stitching
*/
tsv_for_post
    .flatten()
    .map{it -> [it.baseName, it]}
    .set{tsvs_with_names}


tsvs_for_stitching
    .flatten()
    .splitCsv(header:true, sep:"\t")
    .map{it -> [it.measurement_name, it.Stitching_Z, it.gap]}
    .groupTuple()
    .map{it -> [it[0], it[1][0], it[2][0]]}
    .set{stitching_features}


/*
    Acapella stitching
*/
process stitch {
    echo true
    storeDir params.out_dir +"/" + params.proj_code + params.on_corrected
    container '/lustre/scratch117/cellgen/team283/tl10/sifs/acapella-1.1.8.sif'
    containerOptions '-B ' + params.mount_point + ':/data_in/'

    memory '35 GB'

    input:
    tuple val(meas), val(z_mode), val(gap) from stitching_features


    output:
    tuple val(base), path("${base}_${z_mode}") into stitched_meas_for_log

    script:
    base = file(meas).getName()
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/Images/Index.idx.xml" -s OutputDir="./${base}_${z_mode}" -s ZProjection="${z_mode}" -s OutputFormat=tiff -s Silent=false -s Wells="ALL" -s Fields="${params.fields}" -s Channels="ALL" -s Planes="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


/*
    Generate rendering.yaml for each image and update the tsv for OMERO import
*/
/*process post_process {*/
    /*echo true*/
    /*conda baseDir + '/conda_env.yaml'*/
    /*errorStrategy "retry"*/
    /*[>storeDir params.mount_point + '0Misc/stitching_single_tsvs'<]*/
    /*publishDir params.mount_point + '0Misc/stitching_single_tsvs', mode:"copy"*/

    /*input:*/
    /*tuple val(meas), path(meas_folder), path(tsv) from stitched_meas_for_log.join(tsvs_with_names)*/

    /*output:*/
    /*path "${meas_folder}.tsv" into updated_log*/

    /*script:*/
    /*"""*/
    /*python ${baseDir}/post_process.py -dir $meas_folder -log_tsv $tsv -server ${params.server} -mount_point ${params.mount_point}*/
    /*"""*/
/*}*/


/*
    Rename the files to be biologically-relevant
*/
/*process rename {*/
    /*echo true*/
    /*publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"*/
    /*conda baseDir + '/conda_env.yaml'*/

    /*input:*/
    /*path tsvs from updated_log.collect{it}*/

    /*output:*/
    /*path "${params.proj_code}*${params.stamp}.tsv" into tsv_for_import*/

    /*"""*/
    /*python ${baseDir}/rename.py -tsvs $tsvs -export_dir "${params.out_dir}" -project_code "${params.proj_code}" -stamp ${params.stamp} -mount_point ${params.mount_point}*/
    /*#-corrected ${params.on_corrected}*/
    /*"""*/
/*}*/


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

