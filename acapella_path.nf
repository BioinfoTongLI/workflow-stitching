#!/usr/bin/env nextflow

params.log = '/nfs/team283_imaging/TL_SYN/log_files/NS_DSP 12R.xlsx'
params.root = "/nfs/team283_imaging/0HarmonyExports/"
params.zdim_mode = 'max'
params.server = "internal.imaging.sanger.ac.uk"
params.out_dir = "/nfs/team283_imaging/0HarmonyStitched/"
/*params.out_dir = "/home/ubuntu/Documents/acapella-stitching"*/
do_stitching = false
gap = 15000
rename = !do_stitching


process xlsx_to_csv {
    conda 'conda_env.yaml'
    storeDir "/nfs/team283_imaging/TL_SYN/log_files_processed/"
    /*echo true*/

    output:
    path "$stem*.tsv" into csv_with_export_paths
    /*stdout export_paths*/

    script:
    stem = file(params.log).baseName
    """
    python ${workflow.projectDir}/xlsx_2_csv.py -xlsx "$params.log" -root $params.root
    """
}

csv_with_export_paths.splitCsv(header:true, sep:"\t")
    .map{it.full_export_location}
    .set{export_paths}

process stitch {
    echo true
    publishDir params.out_dir, mode:"copy"
    // errorStrategy 'ignore'

    input:
    /*each meas from export_paths.splitText()*/
    val meas from export_paths

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
    cache "lenient"
    echo true
    publishDir '/nfs/team283_imaging/0Misc/tsv_for_import', mode:"copy"
    conda 'conda_env.yaml'

    when:
    rename

    output:
    path "${proj_code}*.tsv" optional true into import_csv

    script:
    proj_code = 'NS_DSP'
    """
    python ${workflow.projectDir}/process_log.py -xlsx "$params.log" -stitched_root "${params.out_dir}${proj_code}" -proj_code ${proj_code} -server ${params.server} --rename
    """
}


process generate_rendering {
    echo true
    cache "lenient"
    conda 'conda_env.yaml'
    publishDir "/nfs/team283_imaging/TL_SYN/ymls", mode:"copy"

    when:
    rename

    input:
    path tsv from import_csv

    output:
    tuple path(tsv), path("*.render.yml") into for_moving_ymls

    script:
    """
    python ${workflow.projectDir}/generate_rendering.py -tsv $tsv
    """
}


process move_yml_to_stitched_img_folder {
    echo true
    conda 'conda_env.yaml'

    input:
    tuple path(tsv), path(ymls) from for_moving_ymls

    script:
    """
    python ${workflow.projectDir}/move_yml_to_img_folder.py -tsv "$tsv" -ymls $ymls
    """
}
