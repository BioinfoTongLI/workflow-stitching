#!/usr/bin/env nextflow

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/log_files/2020.10.12 CC Pan Immune Project Phenix log RNAscope 3plex probes.xlsx'
params.proj_code = "CC_PAN"

params.out_dir = params.mount_point + "0HarmonyStitched/"
params.server = "imaging.internal.sanger.ac.uk"
/*params.server = "omero.sanger.ac.uk"*/

params.z_mode = 'none'
params.stamp = ''
params.gap = 2000


process xlsx_to_tsv {
    /*echo true*/
    cache "lenient"
    conda workflow.projectDir + '/conda_env.yaml'
    /*publishDir params.mount_point + "/TL_SYN/log_files_processed/", mode:"copy"*/

    output:
    path "*.tsv" into csv_with_export_paths

    script:
    stem = file(params.log).baseName
    """
    python ${workflow.projectDir}/xlsx_2_tsv.py -xlsx "$params.log" -root $params.mount_point -gap ${params.gap}
    """
}

csv_with_export_paths.splitCsv(header:true, sep:"\t")
    .map{it -> [it.measurement_name, it.Stitching_Z, it.gap]}
    .set{stitching_features}

/*stitching_features.view{it}*/

process stitch {
    echo true
    storeDir params.out_dir +"/" + params.proj_code
    container 'acapella-tong:1.1.6'
    containerOptions '--volume ' + params.mount_point + ':/data_in/:ro'

    input:
    tuple val(meas), val(z_mode), val(gap) from stitching_features

    output:
    path base into stitched_meas_for_log, stitched_meas_for_rendering

    script:
    base = file(meas).getName()
    if (params.z_mode == ''){
        params.z_mode = 'max'
    }
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/Images/Index.idx.xml" -s OutputDir="./$base" -s ZProjection="${params.z_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


process post_process {
    cache "lenient"
    echo true
    conda workflow.projectDir + '/conda_env.yaml'
    /*storeDir workflow.projectDir + '/single_tsvs'*/

    input:
    path meas_folder from stitched_meas_for_log

    output:
    path "${meas_folder}.tsv" into updated_log

    script:
    """
    python ${workflow.projectDir}/post_process.py -dir $meas_folder -log_xlsx "$params.log" -server ${params.server} -mount_point ${params.mount_point} -z_mode ${params.z_mode}
    """
}


process collect_tsvs{
    echo true
    publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"
    conda workflow.projectDir + '/conda_env.yaml'

    input:
    path tsvs from updated_log.collect{it}

    output:
    path "${params.proj_code}*${params.stamp}.tsv" into tsv_for_import

    """
    python ${workflow.projectDir}/get_import_tsv.py -tsvs $tsvs -export_dir "${params.out_dir}" -project_code "${params.proj_code}" -stamp $params.stamp
    """
}

params.trace_file = ''

trace_file_p = Channel.fromPath(params.trace_file)

process combine {
    echo true
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

