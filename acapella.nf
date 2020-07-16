#!/usr/bin/env nextflow

params.zdim_mode = 'max'
params.stitched_img_dir = ''
params.in_dir = "/nfs/t283_imaging/0HarmonyExports/KR_C19/"
params.target_dir = "/nfs/t283_imaging/0HarmonyExports/KR_C19/0STITCHED/PE-1.1.5"

process generate_tsv_for_stitching{

    input:
	path in_dir from params.in_dir

    output:
	stdout exps

    script:
    out_fname = 'for_stitch.tsv'
    """
    	python ${workflow.projectDir}/scripts/generate_tsv_for_stitching.py \
	-in "${params.in_dir}" -target "${params.target_dir}" -out ${out_fname}
    """
}


process Acapella_Stitching {
    // errorStrategy 'ignore'
    echo true

    input:
        val exp from exps

    shell:
    '''
	echo !{exp}
	echo "!{exp[0]}!{exp[1]}!{exp[2]}"
	indir="!{exp[0]}/!{exp[1]}"
	outdir="!{exp[2]}/!{exp[1]}"

	echo ${indir}
	echo ${outdir}

	#sudo docker run -v "${indir}"/Images:/data_in/Images:ro -v "${outdir}":/data_out:rw --user 0:0 acapella-tong:1.1.5 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" /home/acapella/StitchImage.script
    '''
}
