#!/usr/bin/env nextflow

params.zdim_mode = 'max'

exps = Channel.from(file(params.log))
	.splitCsv()

process Acapella_Stitching {
    errorStrategy 'ignore'
    echo true

    input:
        val exp from exps

    shell:
    '''
	echo "!{exp[0]}!{exp[1]}!{exp[2]}"
	indir="!{exp[0]}/!{exp[1]}"
	outdir="!{exp[2]}/!{exp[1]}"

	#echo ${indir}
	#echo ${outdir}

	#sudo docker run -v "${indir}"/Images:/data_in/Images:ro -v "${outdir}":/data_out:rw --user 0:0 gitlab-registry.internal.sanger.ac.uk/olatarkowska/img-acapella:1.1.2 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" /home/acapella/StitchImage.script
	sudo docker run -v "${indir}"/Images:/data_in/Images:ro -v "${outdir}":/data_out:rw --user 0:0 acapella-tong:1.1.3 acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile=/data_in/Images/Index.idx.xml -s OutputDir=/data_out -s ZProjection="!{params.zdim_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" /home/acapella/StitchImage.script
    '''
}
