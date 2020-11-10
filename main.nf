#!/usr/bin/env nextflow

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/stitching_log_files/KR_C19_exported_20201028.xlsx'
params.proj_code = "KR_C19"

params.out_dir = params.mount_point + "0HarmonyStitched/"
params.server = "imaging.internal.sanger.ac.uk"
/*params.server = "omero.sanger.ac.uk"*/

params.z_mode = 'none'
params.stamp = ''
params.gap = 4000


process xlsx_to_tsv {
    echo true
    cache "lenient"
    conda workflow.projectDir + '/conda_env.yaml'
    /*publishDir params.mount_point + "/TL_SYN/log_files_processed/", mode:"copy"*/

    output:
    path "*.tsv" into csv_with_export_paths

    script:
    """
    python ${workflow.projectDir}/xlsx_2_tsv.py -xlsx "$params.log" -root $params.mount_point -gap ${params.gap} -zmode ${params.z_mode}
    """
}

csv_with_export_paths.splitCsv(header:true, sep:"\t")
    .map{it -> [it.measurement_name, it.Stitching_Z, it.gap]}
    .set{stitching_features}

/*stitching_features.view{it}*/

process stitch {
    echo true
    storeDir params.out_dir +"/" + params.proj_code
    container 'acapella-tong:1.1.7'
    containerOptions '--volume ' + params.mount_point + ':/data_in/:ro'

    memory '35 GB'

    input:
    tuple val(meas), val(z_mode), val(gap) from stitching_features

    output:
    path "${base}_${z_mode}" into stitched_meas_for_log, stitched_meas_for_rendering

    script:
    base = file(meas).getName()
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/Images/Index.idx.xml" -s OutputDir="./${base}_${z_mode}" -s ZProjection="${z_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


process post_process {
    echo true
    conda workflow.projectDir + '/conda_env.yaml'
    /*storeDir params.mount_point + '0Misc/stitching_single_tsvs'*/
    publishDir params.mount_point + '0Misc/stitching_single_tsvs', mode:"copy"

    memory '45 GB'

    input:
    path meas_folder from stitched_meas_for_log

    output:
    path "${meas_folder}.tsv" into updated_log

    script:
    """
    python ${workflow.projectDir}/post_process.py -dir $meas_folder -log_xlsx "$params.log" -server ${params.server} -mount_point ${params.mount_point}
    """
}


process rename {
    echo true
    publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"
    conda workflow.projectDir + '/conda_env.yaml'

    input:
    path tsvs from updated_log.collect{it}

    output:
    path "${params.proj_code}*${params.stamp}.tsv" into tsv_for_import

    """
    python ${workflow.projectDir}/rename.py -tsvs $tsvs -export_dir "${params.out_dir}" -project_code "${params.proj_code}" -stamp ${params.stamp} -mount_point ${params.mount_point}
    """
}

params.trace_file = ''

trace_file_p = Channel.fromPath(params.trace_file)

process combine {
    echo true
    errorStrategy "ignore"
    conda workflow.projectDir + '/conda_env.yaml'
    publishDir params.mount_point +"0Misc/stitching_merged_log", mode:"copy"

    input:
    path log_p from tsv_for_import
    path trace from trace_file_p

    output:
    path "${params.proj_code}_merge_${params.stamp}.tsv"

    script:
    """
    python ${workflow.projectDir}/log_trace_combine.py -log $log_p -trace ${trace} -out_stem ${params.proj_code}_merge_${params.stamp}
    """
}

