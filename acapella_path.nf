#!/usr/bin/env nextflow

params.root = "/nfs/t283_imaging/0HarmonyExports/JSP_HSS"
params.out_dir = "/nfs/0HarmonyStitched/JSP_HSS"
params.zdim_mode = 'max'

meas_dirs = Channel.fromPath(params.root + "/20081*/Images/Index.idx.xml",
	checkIfExists:true).map{file -> file.parent.parent }

cluster = false

process stitch {
    echo true
    publishDir params.out_dir, mode:"copy"
    // errorStrategy 'ignore'

    //maxForks 1
    input:
	path meas from meas_dirs

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
