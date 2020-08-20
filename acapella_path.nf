#!/usr/bin/env nextflow

params.proj_code = 'JSP_HSS'
params.root = "/nfs/team283_imaging/0HarmonyExports/" + params.proj_code
params.out_dir = "/nfs/0HarmonyStitched/" + params.proj_code
params.log = '/nfs/team283_imaging/TL_SYN/20200820_stitching_request.xlsx'
params.zdim_mode = 'max'

meas_dirs = Channel.fromPath(params.root + "/200818*/Images/Index.idx.xml",
	checkIfExists:true).map{file -> file.parent.parent }

cluster = true
rename = false
do_stitching = false

process stitch {
    echo true
    publishDir params.out_dir, mode:"copy"
    // errorStrategy 'ignore'

    //maxForks 1

    input:
	path meas from meas_dirs

    when:
	do_stitching

    shell:
    if (cluster) {
	"""
	docker run -v "${params.root}/$meas"/Images:/data_in/Images:ro -v "${params.out_dir}/$meas":/data_out:rw --user 0:0 acapella-tong:1.1.5 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" /home/acapella/StitchImage.script
	"""
    } else {
	"""
	docker run -v "${params.root}/$meas"/Images:/data_in/Images:ro -v "${params.out_dir}/$meas":/data_out:rw --user 0:0 acapella-tong-touching:1.1.5 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" /home/acapella/StitchImage.script
	"""
    }
}

process rename {
    echo true
    publishDir './tsvs', mode:"copy"

    input:
	path params.log

    when:
	rename

    output:
	path '*.tsv'

    """
	python ${workflow.projectDir}/process_log.py -xlsx $params.log -stitched_root ${params.out_dir} -proj_code ${params.proj_code} --rename
    """
}
