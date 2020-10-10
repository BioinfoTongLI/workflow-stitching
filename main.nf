#!/usr/bin/env nextflow

mount_point = "/nfs/team283_imaging/"
params.log = mount_point + '0Misc/log_files/testset.xlsx'
params.proj_code = "test"

params.out_dir = mount_point + "0HarmonyStitched/"
params.server = "imaging.internal.sanger.ac.uk"
/*params.server = "omero.sanger.ac.uk"*/

params.z_mode = 'max'


process xlsx_to_csv {
    /*echo true*/
    cache "lenient"
    conda workflow.projectDir + '/conda_env.yaml'
    publishDir mount_point + "/TL_SYN/log_files_processed/", mode:"copy"

    output:
    path "*.tsv" into csv_with_export_paths

    script:
    stem = file(params.log).baseName
    """
    python ${workflow.projectDir}/xlsx_2_tsv.py -xlsx "$params.log" -root $mount_point
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
    containerOptions '--volume ' + mount_point + ':/data_in/:ro'

    input:
    tuple val(meas), val(z_mode), val(gap) from stitching_features

    output:
    path base into stitched_meas_for_log, stitched_meas_for_rendering

    script:
    base = file(meas).getName()
    if (z_mode == ''){
        z_mode  = 'max'
    }
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/Images/Index.idx.xml" -s OutputDir="./$base" -s ZProjection="${z_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


process post_process {
    cache "lenient"
    echo true
    conda workflow.projectDir + '/conda_env.yaml'
    storeDir './single_tsvs'

    input:
    path meas_folder from stitched_meas_for_log

    output:
    path "${meas_folder}.tsv" into updated_log

    script:
    """
    python ${workflow.projectDir}/post_process.py -dir $meas_folder -log_xlsx "$params.log" -server ${params.server}
    """
}


process collect_tsvs{
    echo true
    publishDir mount_point + '0Misc/tsv_for_import', mode: "copy"
    conda workflow.projectDir + '/conda_env.yaml'

    input:
    path tsvs from updated_log.collect{it}

    output:
    path "${params.proj_code}*.tsv"

    """
    python ${workflow.projectDir}/get_import_tsv.py -tsvs $tsvs -export_dir "${params.out_dir}" -project_code "${params.proj_code}"
    """
}
