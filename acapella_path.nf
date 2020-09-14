#!/usr/bin/env nextflow

params.log = '/nfs/team283_imaging/TL_SYN/log_files/20200914_stitching_request_Jun.xlsx'
params.root = "/nfs/team283_imaging/0HarmonyExports/"
params.zdim_mode = 'max'
params.out_dir = "/nfs/0HarmonyStitched/"
do_stitching = false
gap = 15000
rename = !do_stitching

process xlsx_to_csv {
    conda "pandas xlrd"
    publishDir "/nfs/TL_SYN/log_files_processed/", mode:"copy"
    /*echo true*/

    output:
    path "$stem*.csv" into csv_with_export_paths
    stdout export_paths

    script:
    stem = file(params.log).baseName
    """
    python ${workflow.projectDir}/xlsx_2_csv.py -xlsx "$params.log" -root $params.root
    """
}

/*csv_with_export_paths.splitCsv(header:true)*/
    /*.map{it.full_export_location}*/
    /*.set{export_paths}*/

process stitch {
    echo true
    publishDir params.out_dir, mode:"copy"
    // errorStrategy 'ignore'

    input:
    each meas from export_paths.splitText()

    when:
    do_stitching

    script:
    meas = meas.trim()
    base = file(meas).getName()
    proj_code = file(file(meas).getParent()).getName()
    """
    docker run -v "$meas"/Images:/data_in/Images:ro -v "${params.out_dir}/$proj_code/$base":/data_out:rw --user 0:0 acapella-tong:1.1.6 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="${params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


process rename {
    echo true
    publishDir '/nfs/TL_SYN/tsv', mode:"copy"
    conda 'tqdm xlrd pandas'

    when:
    rename

    output:
    path '*.tsv'

    script:
    proj_code = 'LY_BRC'
    """
    python ${workflow.projectDir}/process_log.py -xlsx "$params.log" -stitched_root "${params.out_dir}/$proj_code" -proj_code ${proj_code} --rename
    """
}
