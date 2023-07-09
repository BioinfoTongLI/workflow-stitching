#!/usr/bin/env nextflow

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/stitching_log_files/KR_C19_exported_20201028.xlsx'
params.proj_code = "KR_C19"

params.out_dir = "${params.mount_point}/0HarmonyStitched/" // default location, don't change
params.server = "omero.sanger.ac.uk" // or "imaging.internal.sanger.ac.uk" deprecated

params.z_mode = 'none' // or max
params.stamp = '' // time stamp of execution
params.gap = 4000 // maximum distance between tiles
params.fields = 'ALL' // selection of field of views
params.on_corrected = "" // or "_corrected" for flat-field corrected tiles
params.index_file = "Images/Index.xml"

/*
 *  Convert the xlsx file to .tsv that is nextflow friendly
 *  some sanity check is also performed here
 */
process xlsx_to_tsv {
    debug true

    container "/lustre/scratch126/cellgen/team283/imaging_sifs/stitching_processing.sif"
    containerOptions "-B /nfs,/lustre"

    input:
    tuple val(meta), path(log_file)

    output:
    path "*.tsv"

    script:
    """
    xlsx_2_tsv.py \
           -xlsx "${log_file}" \
           -root ${meta.mount_point} \
           -gap ${meta.gap} \
           -zmode ${meta.z_mode} \
    """
}

/*
 *  Acapella stitching
 */
process stitch {
    debug true

    /*container '/nfs/cellgeni/singularity/images/imaging/acapella-stitching-1.1.8.2023.sif'*/
    container '/lustre/scratch126/cellgen/team283/imaging_sifs/acapella-stitching-1.1.8.2023.sif'
    containerOptions "-B /lustre,/nfs"
    storeDir "${params.out_dir}/${params.proj_code}"

    cpus 6
    memory '75 GB'

    input:
    tuple val(meas), val(z_mode), val(gap), val(index_file)

    output:
    tuple val(base), path("${base}_${z_mode}")

    script:
    base = file(meas).getName()
    """
    echo "[+] Stitching ${index_file}"

    acapella -license /home/acapella/AcapellaLicense.txt \
             -s IndexFile="${index_file}" \
             -s OutputDir="./${base}_${z_mode}" \
             -s ZProjection="${z_mode}" \
             -s OutputFormat=tiff \
             -s Silent=false \
             -s Wells="ALL" \
             -s Fields="${params.fields}" \
             -s Channels="ALL" \
             -s Planes="ALL" \
             -s Gap=${gap} \
             /home/acapella/StitchImage.script
    """
}


/*
 *  Generate rendering.yaml for each image and update the tsv for OMERO import
 */
process post_process {
    debug true

    errorStrategy "retry"
    container "/lustre/scratch126/cellgen/team283/imaging_sifs/stitching_processing.sif"
    containerOptions "-B ${baseDir}:/codes,/nfs,/lustre"
    publishDir "${params.mount_point}/0Misc/stitching_single_tsvs", mode:"copy"
    memory '120 GB'

    input:
    tuple val(meas), path(meas_folder), path(tsv)//from stitched_meas_for_log.join(tsvs_with_names)

    output:
    path "${meas_folder}.tsv"// into updated_log

    script:
    """
    python /codes/post_process.py \
           -dir $meas_folder \
           -log_tsv $tsv \
           -server ${params.server} \
           -mount_point ${params.mount_point}
    """
}


/*
    Rename the files to be biologically-relevant
*/
process rename {
    debug true

    container "/lustre/scratch126/cellgen/team283/imaging_sifs/stitching_processing.sif"
    containerOptions "-B /nfs,/lustre"
    publishDir "${params.mount_point}/0Misc/stitching_tsv_for_import", mode: "copy"
    /*
    Simon added as pipeline produced error:
    Sorry you have requested more memory than the defaults
    for this cluster, which is currently0 MB. Please set
    -M mem value
    */
    memory '8 GB'

    input:
    path tsvs// from updated_log.collect{it}

    output:
    path "${params.proj_code}*${params.stamp}.tsv" //into tsv_for_import

    """
    python /codes/rename.py \
           -tsvs $tsvs \
           -export_dir "${params.out_dir}" \
           -project_code "${params.proj_code}" \
           -stamp ${params.stamp} \
           -mount_point ${params.mount_point}
    #-corrected ${params.on_corrected}
    """
}
