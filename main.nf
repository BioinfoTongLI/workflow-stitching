#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.mount_point = "/nfs/team283_imaging/"
params.log = params.mount_point + '0Misc/stitching_log_files/2022.05.04_iNeurons.xlsx'
params.proj_code = "TL_SYN"
params.from = 0
params.to = -1

params.out_dir = params.mount_point + "0HarmonyStitched/" // default location, don't change
params.server = "omero.sanger.ac.uk" // or "imaging.internal.sanger.ac.uk" deprecated

params.z_mode = 'max' // none or max
params.stamp = '' // time stamp of execution
params.gap = 4000 // maximum distance between tiles
params.fields = 'ALL' // selection of field of views
params.on_corrected = "" // "" or "_corrected" for flat-field corrected tiles
params.index_file = "Images/Index.xml"

container_path = "gitlab-registry.internal.sanger.ac.uk/tl10/acapella-stitching:latest"
sif_folder = "/lustre/scratch126/cellgen/team283/imaging_sifs/"
debug = true
params.is_slide = false
params.hcs_zarr = params.out_dir + "/HCS_zarrs"

params.do_ashlar_stitching = false
params.reference_ch = 0
params.max_shift = 100


/*
    Convert the xlsx file to .tsv that is nextflow friendly
    some sanity check is also performed here
*/
process xlsx_to_tsv {
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"

    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':' + params.mount_point :
        '-v ' + params.mount_point + ':' + params.mount_point}"

    input:
    file log_file
    val mount_point
    val gap
    val z_mode
    val on_corrected
    val PE_index_file_anchor

    output:
    file "*.tsv"

    script:
    """
    xlsx_2_tsv.py --xlsx ${log_file} --root ${mount_point} --gap ${gap} --zmode ${z_mode} --export_loc_suffix "${on_corrected}" --PE_index_file_anchor ${PE_index_file_anchor}
    """
}


process PE_index_to_OME_index {
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'your.sif' :
        container_path }"

    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':/data_in/:ro' :
        '-v ' + params.mount_point + ':/data_in/:ro'}"

    /*storeDir "./test_ashlar"*/

    input:
    tuple val(meas_folder), val(max_proj), val(gap)
    val index_file

    output:
    path ("*.index.xml"), emit: ome_index

    script:
    """
    index_file_cropping.py --index_file "/data_in/${meas_folder}/${index_file}"
    """
}


process PE_to_ome_zarr {
    debug debug

    label "default"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/bf2raw-0.5.0rc1.sif':
        'quay.io/bioinfotongli/bioformats2raw:0.5.0rc1'}"

    /*containerOptions "${workflow.containerEngine == 'singularity' ?*/
        /*'-B ' + params.mount_point + ':/data_in/:ro' :*/
        /*'-v ' + params.mount_point + ':/data_in/:ro'}"*/

    storeDir zarr_dir

    input:
    tuple val(ind), path(mea_folder)
    val(ome_index)
    tuple val(hardware), val(camera_dim)

    output:
    tuple val(stem), val(ind), path("${stem}.zarr"), val(hardware)

    script:
    if (hardware == 'nemo'){
        stem = file(ome_index).baseName
    } else {
        stem = file(mea_folder).baseName
    }
    """
    /usr/local/bin/_entrypoint.sh bioformats2raw -w ${camera_dim} -h ${camera_dim} $mea_folder/${ome_index} "${stem}.zarr"
    """
}


process MIP_zarr_to_tiled_tiff {
    debug debug

    /*label "default"*/
    cpus 20
    memory 120.Gb
    queue 'imaging'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/ashlar_preprocess.sif':
        'ashlar_preprocess:latest'}"
    clusterOptions "-m 'node-11-3-3'"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    tuple val(stem), val(ind), path(ome_zarr), val(hardware)
    tuple val(from), val(to)

    output:
    tuple val(stem), val(ind), path(out_file_name), emit: tif
    tuple val(stem), val(ind), path(xml_name), emit: xml

    script:
    out_file_name = "${stem}_${from}_${to}.ome.tif"
    xml_name = "${stem}.xml"
    """
    mip_zarr_to_tiled_tiff.py ${hardware} -zarr_in ${ome_zarr} -out_tif "${out_file_name}" -select_range [${from},${to}]
    cp ${ome_zarr}/OME/METADATA.ome.xml "$xml_name"
    """
}


/*
    Acapella stitching
*/
process stitch {
    tag "$meas_folder"
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/acapella-1.1.8.sif':
        'acapella-in-docker'}"
    containerOptions "-B ${params.mount_point}:/data_in/:ro,/tmp/:/tmp/acapella/:rw"
    storeDir params.out_dir + "/" + params.proj_code + params.on_corrected

    memory '60 GB'

    input:
    tuple val(meas), val(z_mode), val(gap)
    val fields
    val index_file

    output:
    tuple val(base), path(meas_folder)

    script:
    base = file(meas).getName()
    meas_folder = "${base}_${z_mode}"
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/$meas/${index_file}" -s OutputDir="${meas_folder}" -s ZProjection="${z_mode}" -s OutputFormat=tiff -s Silent=false -s Wells="ALL" -s Fields="${fields}" -s Channels="ALL" -s Planes="ALL" -s Gap=${gap} /home/acapella/StitchImage.script
    """
}


/*
    Generate rendering.yaml for each image and update the tsv for OMERO import
*/
process post_process {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':' + params.mount_point :
        '-v ' + params.mount_point + ':' + params.mount_point}"

    errorStrategy "retry"

    storeDir params.mount_point + '0Misc/stitching_single_tsvs'
    /*publishDir params.mount_point + '0Misc/stitching_single_tsvs', mode:"copy"*/

    input:
    tuple val(meas), path(meas_folder), path(tsv)
    val server
    val mount_point

    output:
    path "${meas_folder}.tsv"

    script:
    """
    post_process.py --dir_in $meas_folder --log_tsv $tsv --server ${server} --mount_point ${mount_point}
    """
}


/*
    Rename the files to be biologically-relevant
*/
process rename {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "${workflow.containerEngine == 'singularity' ?
        '-B ' + params.mount_point + ':' + params.mount_point + ':rw' :
        '-v ' + params.mount_point + ':' + params.mount_point + ':rw'}"

    publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"

    input:
    path tsvs
    val out_dir
    val proj_code
    val stamp
    val mount_point
    val on_corrected

    output:
    path "${proj_code}*${stamp}.tsv"

    script:
    """
    rename.py $tsvs --export_dir "${out_dir}" --project_code "${proj_code}" --stamp "${stamp}" --mount_point "${mount_point}" --corrected "${on_corrected}"
    """
}


process Generate_companion_ome {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "-B ${params.mount_point}"
    /*publishDir params.mount_point + '0Misc/stitching_tsv_for_import', mode: "copy"*/

    input:
    tuple val(base), path(meas_folder)

    output:
    tuple val(base), path("${meas_folder}/*.companion.ome"), path("${meas_folder}/*.ome.tiff")

    script:
    """
    generate_companion_ome.py --images_path ${meas_folder}
    cp *.companion.ome ${meas_folder}
    """
}


process bf2raw {
    tag "${companion}"
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/bf2raw-0.5.0rc1.sif':
        'openmicroscopy/bioformats2raw:0.5.0rc1'}"
    storeDir params.hcs_zarr

    input:
    tuple val(stem), path(companion), path(tifs)

    output:
    tuple val(stem), path("${stem}.zarr")

    script:
    """
    /usr/local/bin/_entrypoint.sh bioformats2raw ./${companion} "${stem}.zarr"
    #/opt/bioformats2raw/bin/bioformats2raw ./${companion} "${stem}.zarr"
    """
}


process ashlar_single_stitch {
    debug debug

    cpus 2
    memory 15.Gb
    queue 'imaging'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/ashlar.sif':
        "ashlar:latest" }"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    tuple val(stem), val(ind), path(ome_tifs)
    val(ref_ch)
    val(max_shift)

    output:
    tuple val(stem), val(ind), path(out_name), emit: stitched_tif

    script:
    out_name = "${stem}_stitched_ref_ch_${ref_ch}_max_shift_${max_shift}.ome.tif"
    """
    ashlar -c ${ref_ch} $ome_tifs -m ${max_shift} -o "${out_name}"
    """
}

process ashlar_stitch_register {
    debug debug

    cpus 2
    memory 15.Gb
    queue 'imaging'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/ashlar.sif':
        "ashlar:latest" }"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    path(ome_tifs)
    val(ref_ch)
    val(max_shift)

    output:
    path(out_name)

    script:
    out_name = "stitched_ref_ch_${ref_ch}_max_shift_${max_shift}.ome.tif"
    """
    ashlar -c ${ref_ch} $ome_tifs -m ${max_shift} -o ${out_name}
    """
}


process update_channel_names {
    debug debug

    /*label "default"*/
    cpus 1
    memory 30.Gb
    queue 'imaging'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/ashlar_preprocess.sif':
        'ashlar_preprocess:latest'}"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    tuple val(stem), val(ind), path(ome_tif), path(ome_xml)

    output:
    tuple val(stem), val(ind), path(out_file_name), emit: tif

    script:
    tif_stem = file(ome_tif).baseName
    out_file_name = "${tif_stem}_with_channel_names.ome.tif"
    """
    cp ${ome_tif} "${out_file_name}"
    update_channel_names.py -in_tif ${ome_tif} -out_tif "${out_file_name}" -xml_name ${ome_xml}
    """
}
/*
    [Optional, so errorStrategy = "ignore"]
    Append stitching benchmark from nextflow.trace into the tsv log
*/
/*params.trace_file = ''*/

/*trace_file_p = Channel.fromPath(params.trace_file)*/

/*process combine {*/
    /*echo true*/
    /*errorStrategy "ignore"*/
    /*conda baseDir + '/conda_env.yaml'*/
    /*publishDir params.mount_point +"0Misc/stitching_merged_log", mode:"copy"*/

    /*input:*/
    /*path log_p from tsv_for_import*/
    /*path trace from trace_file_p*/

    /*output:*/
    /*path "${params.proj_code}_merge_${params.stamp}.tsv"*/

    /*script:*/
    /*"""*/
    /*python ${baseDir}/log_trace_combine.py -log $log_p -trace ${trace} -out_stem ${params.proj_code}_merge_${params.stamp}*/
    /*"""*/
/*}*/

workflow _metadata_parsing {
    xlsx_to_tsv(channel.fromPath(params.log, checkIfExists: true),
        params.mount_point, params.gap, params.z_mode,
        params.on_corrected, params.index_file)
    /*
        Put parameter channel for stitching
    */
    tsvs_with_names = xlsx_to_tsv.out
        .flatten()
        .map{it -> [it.baseName, it]}
    /*tsvs_with_names.view()*/


    stitching_features = xlsx_to_tsv.out
        .flatten()
        .splitCsv(header:true, sep:"\t")
        .map{it -> [it.measurement_name, it.Stitching_Z, it.gap]}
        .groupTuple()
        .map{it -> [it[0], it[1][0], it[2][0]]}
    /*stitching_features.view()*/

    emit:
    stitching_features
}

workflow {
    stitch(_metadata_parsing.out, params.fields, params.index_file)
    if (params.is_slide) {
        post_process(stitch.out.join(tsvs_with_names), params.server, params.mount_point)
        rename(post_process.out.collect(),
            params.out_dir, params.proj_code, params.stamp,
            params.mount_point, params.on_corrected)
    } else {
        Generate_companion_ome(stitch.out)
        bf2raw(Generate_companion_ome.out)
    }
}

workflow _mip_and_stitch {
    take:
    ome_zarr

    main:
    MIP_zarr_to_tiled_tiff(ome_zarr, [params.from, params.to])
    ashlar_single_stitch(MIP_zarr_to_tiled_tiff.out.tif, params.reference_ch, params.max_shift)
    sorted_list = MIP_zarr_to_tiled_tiff.out.tif
        .toSortedList( { a -> a[1] } )
        .map { allPairs -> allPairs.collect{ meas, ind, f -> file(f) } }
        .collect()
    /*sorted_list.view()*/
    if (params.do_ashlar_stitching) {
        ashlar_stitch_register(sorted_list, params.reference_ch, params.max_shift)
    } else {
        update_channel_names(ashlar_single_stitch.out.stitched_tif.join(MIP_zarr_to_tiled_tiff.out.xml, by: [0, 1]))
    }
}


zarr_dir = "/nfs/team283_imaging/0HarmonyZarr/"
/*zarr_dir = "/nfs/team283_imaging/playground_Tong/temp_nemo1_convert/"*/

workflow ashlar {
    /*_metadata_parsing()*/
    /*_metadata_parsing.out.view()*/
    params.meas_dirs = [["/nfs/team283_imaging/0HarmonyExports/LY_BRC/LY_BRC_AT0002__2022-10-07T17_43_01-Measurement 17/"]]
    hardware = "phenix"
    image_size = 2160
    PE_to_ome_zarr(channel.from(params.meas_dirs), params.index_file, [hardware, image_size])
    _mip_and_stitch(PE_to_ome_zarr.out)
}

workflow nemo {
    params.master_ome_tiff = [
        [0, "/nfs/team283_imaging/Nemo_data/FLNG-3/2021_12_14/MALAT1_1/"],
    ]
    hardware = "nemo1"
    image_size = 1950
    PE_to_ome_zarr(channel.from(params.master_ome_tiff), 'MALAT1_1_MMStack_Test_2-Grid_0_10.ome.tif', [hardware, image_size])
    _mip_and_stitch(PE_to_ome_zarr.out)
}
