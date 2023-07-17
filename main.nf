#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.mount_point = "/nfs/team283_imaging/"

/*PE stitching related parameters*/
params.gap = 4000
params.z_mode = 'max'

params.log = params.mount_point + '0Misc/stitching_log_files/2022.05.04_iNeurons.xlsx'
params.proj_code = "Test_deleteme"
params.from = 0
params.to = -1

params.out_dir = params.mount_point + "0HarmonyStitched/" // default location, don't change

container_path = "gitlab-registry.internal.sanger.ac.uk/tl10/acapella-stitching:latest"
sif_folder = "/lustre/scratch126/cellgen/team283/imaging_sifs/"
debug = true
params.hcs_zarr = params.out_dir + "/HCS_zarrs"

params.do_ashlar_stitching = false
params.reference_ch = 1
params.max_shift = 100

params.image_config = [
    [],
    []
]

include { xlsx_to_tsv; stitch; post_process; rename } from './workflows/PE_stitch'

/*
    Convert raw exported tiles to tiled ome tif using aicsimageio
*/
process Tiles_to_tiled_ome_tif {
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'bioinfotongli/preprocess:latest':
        'bioinfotongli/preprocess:latest'}"
    // publishDir params.out_dir, mode: 'copy'
    publishDir "/lustre/scratch126/cellgen/team283/NXF_WORK/tiled_ome_tiffs", mode: 'copy'

    input:
    tuple val(meta), path(mea_folder), val(master_file)

    output:
    tuple val(meta), path(out_ome_tif)

    script:
    out_ome_tif = "${meta['id']}_tiled.ome.tif"
    """
    tiles_to_tiled_ome_tif.py ${mea_folder}/${master_file} ${out_ome_tif}
    """
}

/*
    Convert image exported tiles to ome zarr using bioformats2raw
*/
process Tiles_to_ome_zarr {
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/bf2raw-0.5.0rc1.sif':
        'quay.io/bioinfotongli/bioformats2raw:0.5.0rc1'}"
    publishDir "/lustre/scratch126/cellgen/team283/NXF_WORK/tiled_ome_tiffs", mode: 'copy'

    input:
    tuple val(meta), path(mea_folder), val(master_file)

    output:
    tuple val(meta), path("${stem}.zarr.zip")

    script:
    def camera_dim = meta['camera_dim']
    if (meta['hardware'] == 'nemo1'){
        stem = file(master_file).baseName
    } else {
        stem = file(mea_folder).baseName
    }
    """
    /usr/local/bin/_entrypoint.sh bioformats2raw -w ${camera_dim} -h ${camera_dim} $mea_folder/${master_file} "${stem}.zarr"
    zip -r "${stem}.zarr.zip" "${stem}.zarr"
    rm -r "${stem}.zarr"
    """
}

process ashlar_single_stitch {
    debug debug

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
    ashlar -c ${ref_ch} $ome_tifs -m ${max_shift} --flip-y -o "${out_name}"
    """
}

process ashlar_stitch_register {
    debug debug

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

// update the channel names in the OME-TIFF using the channel names in the companion OME-XML or the embedded OME-XML
process update_channel_names {
    debug debug

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/ashlar_preprocess.sif':
        'ashlar_preprocess:latest'}"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    tuple val(stem), val(ind), path(ome_tif), path(ome_xml_or_tif)

    output:
    tuple val(stem), val(ind), path(out_file_name), emit: tif

    script:
    tif_stem = file(ome_tif).baseName
    out_file_name = "${tif_stem}_with_channel_names.ome.tif"
    """
    cp ${ome_tif} "${out_file_name}"
    update_channel_names.py -in_tif ${ome_tif} -out_tif "${out_file_name}" -xml_name ${ome_xml_or_tif}
    """
}


process Nemo2_to_tiled_tiff {
    debug debug

    queue 'imaging'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/nemo2_preprocess.sif':
        'nemo2_preprocess:latest'}"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    tuple val(stem), path(master_tif), path(pc2_folder), path(regpc1), path(regpc2), path(ch_config_file)

    output:
    tuple val(stem), path("${out_dir_name}"), emit: tif

    script:
    out_dir_name = "tiff_tiles_${stem}"
    /*out_file_name = "${tif_stem}_with_channel_names.ome.tif"*/
    """
    mkdir ${out_dir_name}
    NEMO2_to_tiles.py --FolderPC1File ${master_tif} --FolderPC2 ${pc2_folder} --beadstack1 ${regpc1} --beadstack2 ${regpc2} --ConfigFile ${ch_config_file} --OutDir ${out_dir_name}
    """
}


process zproj_tiled_tiff {
    debug debug

    queue 'imaging'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/nemo2_preprocess.sif':
        'nemo2_preprocess:latest'}"

    storeDir params.out_dir + "/${params.proj_code}"

    input:
    tuple val(stem), path(tiff_folder)

    output:
    tuple val(stem), val(stem), path("${stem}.ome.tif"), emit: tif

    script:
    """
    Tiles_to_ashlar.py --input_folder ${tiff_folder} --file_out ./${stem}.ome.tif
    """
}

process MIP_zarr_to_tiled_tiff {
    debug debug

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

process Generate_companion_ome {
    debug debug

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        sif_folder + '/stitching_process.sif':
        container_path}"
    containerOptions "-B ${params.mount_point}"
    storeDir "${params.out_dir}/${params.proj_code}"

    input:
    tuple val(base), path(meas_folder), path(tsv_meta_file)

    output:
    tuple val(base), path("${meas_folder}/*.companion.ome")

    script:
    """
    generate_companion_ome.py --images_path ${meas_folder}
    cp *.companion.ome ${meas_folder}
    """
}

workflow PE_STITCH {
    main:
    xlsx_to_tsv(
        channel.from(
            [[['mount_point': params.mount_point, 'gap': params.gap, 'z_mode': params.z_mode],
            file(params.log, checkIfExists : true)]]
        )
    )
    /*
     *  Put parameter channel for stitching
     */
    tsvs_with_names = xlsx_to_tsv.out.flatten()
        .map{it -> [it.baseName, it]}

    stitching_features = xlsx_to_tsv.out.flatten()
        .splitCsv(header:true, sep:"\t")
        .map{it -> [it.measurement_name, it.Stitching_Z, it.gap, it.index_file]}
        .groupTuple()
        .map{it -> [it[0], it[1][0], it[2][0], it[3][0]]}

    stitch(stitching_features)

    emit:
    stitch.out.join(tsvs_with_names)
}

// Stitch with PE's own stitching software and then generate companion ome file for the folder
workflow PE_HCS {
    Generate_companion_ome(PE_STITCH())
}

// Stitch with PE's own stitching software and then rename the files
workflow PE_WSI{
    post_process(PE_STITCH())
    rename(post_process.collect())
}

params.meas_master = [
        [['id': "nemo2_cam_1", 'hardware': "nemo2", 'camera_dim': 1960],
        "/nfs/team283_imaging/Nemo2_data/FLNG_ISS/2023_01_18/Anchor/Cam1_1/Cam1_1_MMStack_Anchor-Grid_0_13.ome.tif"],
        // [['id': "phenix"], "/nfs/team283_imaging/0HarmonyExports/JM_TCA/t217_jm52_20230710_LipocyteProfilerV2_correct568__2023-07-10T16_02_27-Measurement 1/Images/Index.xml"],
        // [['id': "nemo1"], "/nfs/team283_imaging/Nemo_data/TL_CDX/TL_CDX_20220830_mouse_hemisphere/tl10_mouse_brain_20220830_1/tl10_mouse_brain_20220830_1_MMStack_Mouse_brain-Grid_0_4.ome.tif"],

        //Good below
        [['id': "nemo2_cam_2", 'hardware': "nemo2", 'camera_dim': 1960],
        "/nfs/team283_imaging/Nemo2_data/FLNG_ISS/2023_01_18/Anchor/Cam2_1/Cam2_1_MMStack_Pos0.ome.tif"],
    ]

// Use ashlar to stitch PE tiles
workflow ashlar {
    hardware = "phenix"
    image_size = 2160
    Tiles_to_ome_zarr(channel.from(params.meas_master), params.index_file, [hardware, image_size])
    _mip_and_stitch(Tiles_to_ome_zarr.out)
}

// use ashlar to stitch images from single PC (Nemo1) data
workflow nemo {
    params.master_ome_tiff = [
        [0, "/nfs/team283_imaging/Nemo_data/FLNG-3/2021_12_14/MALAT1_1/"],
    ]
    hardware = "nemo1"
    image_size = 1950
    Tiles_to_ome_zarr(channel.from(params.master_ome_tiff), 'MALAT1_1_MMStack_Test_2-Grid_0_10.ome.tif', [hardware, image_size])
    _mip_and_stitch(Tiles_to_ome_zarr.out)
}

// use ashlar to stitch images from dual PC (Nemo2) data
workflow nemo2 {
    hardware = "nemo2"
    /*image_size = 1950*/
    Nemo2_to_tiled_tiff(channel.from(params.image_config))
    zproj_tiled_tiff(Nemo2_to_tiled_tiff.out)
    ashlar_single_stitch(zproj_tiled_tiff.out.tif, params.reference_ch, params.max_shift)
    update_channel_names(ashlar_single_stitch.out.stitched_tif.join(zproj_tiled_tiff.out.tif, by: [0, 1]))
}

workflow {
    images = channel.from(params.meas_master)
        .map{it -> [it[0], file(file(it[1]).parent, checkIfExists:true), file(it[1]).name]}
    // Tiles_to_tiled_ome_tif(images)
    Tiles_to_ome_zarr(images)
}