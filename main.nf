#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/stitching_log_files/20220223_test_Tong.xlsx'
params.proj_code = "TL_SYN"

params.out_dir = params.mount_point + "0HarmonyStitched/"
params.server = "imaging.internal.sanger.ac.uk"
/*params.server = "omero.sanger.ac.uk"*/

params.z_mode = 'max' // none or max
params.stamp = '' // time stamp of execution
params.gap = 4000 // maximum distance between tiles
params.fields = 'ALL' // selection of field of views
params.on_corrected = "" // "" or "_corrected" for flat-field corrected tiles
params.index_file = "Images/Index.xml"

/*
    Convert the xlsx file to .tsv that is nextflow friendly
    some sanity check is also performed here
*/
process xlsx_to_tsv {
    /*echo true*/
    cache "lenient"
    conda baseDir + '/conda_env.yaml'

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
    xlsx_2_tsv.py --xlsx "${log_file}" --root ${mount_point} --gap ${gap} --zmode ${z_mode} --export_loc_suffix "${on_corrected}" --PE_index_file_anchor ${PE_index_file_anchor}
    """
}


/*
    Acapella stitching
*/
process stitch {
    tag "$meas"
    echo true
    container 'gitlab-registry.internal.sanger.ac.uk/cellgeni/containers/acapella'
    containerOptions "-v ${params.mount_point}:/data_in/:ro -u 1000:1000"
    storeDir params.out_dir +"/" + params.proj_code + params.on_corrected

    memory '35 GB'

    input:
    tuple val(meas), val(z_mode), val(gap)
    val fields
    val index_file

    output:
    tuple val(base), path("${base}_${z_mode}") //into stitched_meas_for_log

    script:
    base = file(meas).getName()
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/${index_file}" -s OutputDir="${base}_${z_mode}" -s ZProjection="${z_mode}" -s OutputFormat=tiff -s Silent=false -s Wells="ALL" -s Fields="${fields}" -s Channels="ALL" -s Planes="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


/*
    Generate rendering.yaml for each image and update the tsv for OMERO import
*/
process post_process {
    echo true
    conda baseDir + '/conda_env.yaml'
    /*errorStrategy "retry"*/
    /*storeDir params.mount_point + '0Misc/stitching_single_tsvs'*/
    publishDir params.mount_point + '0Misc/stitching_single_tsvs', mode:"copy"

    input:
    tuple val(meas), path(meas_folder), path(tsv)

    output:
    path "${meas_folder}.tsv"

    script:
    """
    post_process.py --dir_in $meas_folder --log_tsv $tsv --server ${params.server} --mount_point ${params.mount_point}
    """
}


/*
    Rename the files to be biologically meaningful
*/
process rename {
    echo true
    publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"
    conda baseDir + '/conda_env.yaml'

    input:
    path tsvs
    val out_dir
    val proj_code
    val stamp
    val mount_point
    val on_corrected

    output:
    path "${proj_code}*${stamp}.tsv"

    """
    rename.py $tsvs --export_dir "${out_dir}" --project_code "${proj_code}" --stamp "${stamp}" --mount_point "${mount_point}" --corrected "${on_corrected}"
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
    xlsx_to_tsv(channel.fromPath(params.log, checkIfExists: true), params.mount_point, params.gap, params.z_mode, params.on_corrected, params.index_file)
    /*
        Put parameter channel for stitching
    */
    xlsx_to_tsv.out
        .flatten()
        .map{it -> [it.baseName, it]}
        .set{tsvs_with_names}


    xlsx_to_tsv.out
        .flatten()
        .splitCsv(header:true, sep:"\t")
        .map{it -> [it.measurement_name, it.Stitching_Z, it.gap]}
        .groupTuple()
        .map{it -> [it[0], it[1][0], it[2][0]]}
        .set{stitching_features}

    stitch(stitching_features, params.fields, params.index_file)
    post_process(stitch.out.join(tsvs_with_names))
    rename(post_process.out.collect(),
        params.out_dir, params.proj_code, params.stamp,
        params.mount_point, params.on_corrected)
}
