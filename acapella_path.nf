#!/usr/bin/env nextflow

params.root = "/nfs/t283_imaging/0HarmonyExports/KR_C19"
params.out_dir = "/nfs/HarmonyExports/KR_C19/0STITCHED/PE-1.1.5"
params.zdim_mode = 'max'

meas_dirs = Channel.fromPath(params.root + "/*/Images/Index.idx.xml",
	checkIfExists:true).map{file -> file.parent.parent }

process generate_tsv_for_stitching{
    echo true
    // errorStrategy 'ignore'

    input:
	path meas from meas_dirs

    shell:
    """
	sudo docker run -v "${params.root}/$meas"/Images:/data_in/Images:ro -v "${params.out_dir}/$meas":/data_out:rw --user 0:0 acapella-tong:1.1.5 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" /home/acapella/StitchImage.script
    """
}
