#!/usr/bin/env nextflow

params.proj_code = 'JSP_HSS'
params.root = "/nfs/team283_imaging/0HarmonyExports/" + params.proj_code
params.out_dir = "/nfs/0HarmonyStitched/" + params.proj_code
//params.out_dir = "$PWD"
params.log = '/nfs/team283_imaging/TL_SYN/log_files/2020.08.26 VK_VIS Phenix log Visium TO slide adult thymus.xlsx'
params.zdim_mode = 'max'


meas_dirs = Channel.fromPath(params.root + "/JSP_HSS_MM1000[6-7]*b/Images/Index.idx.xml",
	checkIfExists:true).map{file -> file.parent.parent }

do_stitching = true
gap = 15000
rename = !do_stitching


process stitch {
    echo true
    publishDir params.out_dir, mode:"copy"
    // errorStrategy 'ignore'

    input:
	path meas from meas_dirs

    when:
	do_stitching

    shell:
	"""
	docker run -v "${params.root}/$meas"/Images:/data_in/Images:ro -v "${params.out_dir}/$meas":/data_out:rw --user 0:0 acapella-tong:1.1.6 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
	"""
}


process rename {
    echo true
    publishDir './tsvs', mode:"copy"
    conda 'tqdm xlrd pandas'

    input:
	path params.log

    when:
	rename

    output:
	path '*.tsv'

    """
	python ${workflow.projectDir}/process_log.py -xlsx "$params.log" -stitched_root ${params.out_dir} -proj_code ${params.proj_code} --rename
    """
}
