#!/usr/bin/env nextflow

mount_point = "/nfs/team283_imaging/"
params.log = mount_point + '0Misc/log_files/RV_END for OMERO 250920.xlsx'
params.out_dir = mount_point + "0HarmonyStitched/"
params.server = "internal.imaging.sanger.ac.uk"
params.proj_code = "RV_END"
params.zdim_mode = 'max'
/*params.out_dir = "/home/ubuntu/Documents/acapella-stitching"*/

do_stitching = true
gap = 15000
rename = !do_stitching


process xlsx_to_csv {
    cache "lenient"
    conda 'conda_env.yaml'
    publishDir mount_point + "/TL_SYN/log_files_processed/", mode:"copy"
    /*echo true*/

    output:
    path "*.tsv" into csv_with_export_paths
    /*stdout export_paths*/

    script:
    stem = file(params.log).baseName
    """
    python ${workflow.projectDir}/xlsx_2_csv.py -xlsx "$params.log" -root $mount_point
    """
}

csv_with_export_paths.splitCsv(header:true, sep:"\t")
    .map{it.measurement_name}
    .set{export_paths}

process stitch {
    storeDir params.out_dir +"/" + params.proj_code
    container 'acapella-tong:1.1.6'
    containerOptions '--volume ' + mount_point + ':/data_in/:ro'
    echo true
    /*errorStrategy 'ignore'*/

    when:
    do_stitching

    input:
    val meas from export_paths

    output:
    path base into stitched_meas_for_log, stitched_meas_for_rendering

    script:
    base = file(meas).getName()
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/Images/Index.idx.xml" -s OutputDir="./$base" -s ZProjection="${params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


process post_process {
    cache "lenient"
    echo true
    conda 'conda_env.yaml'
    /*storeDir './single_tsvs'*/

    input:
    path meas_folder from stitched_meas_for_log

    output:
    path "${meas_folder}.tsv" into updated_log

    script:
    """
    python ${workflow.projectDir}/post_process.py -dir $meas_folder -log_xlsx "$params.log" -server ${params.server}

    #python ${workflow.projectDir}/process_log.py -xlsx "$params.log" -stitched_root "${params.out_dir}${params.proj_code}" -proj_code ${params.proj_code}
    """
}


process collect_tsvs{
    echo true
    publishDir mount_point + '0Misc/tsv_for_import', mode: "copy"
    conda 'conda_env.yaml'

    input:
    path tsvs from updated_log.collect{it}

    output:
    path "${params.proj_code}*.tsv"

    """
    python ${workflow.projectDir}/get_import_tsv.py -tsvs $tsvs -export_dir "${params.out_dir}" -project_code "${params.proj_code}"
    """
}
