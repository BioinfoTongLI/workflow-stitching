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

include { two_step_recon } from './workflows/preprocess'

zarr_dir = "/nfs/team283_imaging/0HarmonyZarr/"
/*zarr_dir = "/nfs/team283_imaging/playground_Tong/temp_nemo1_convert/"*/

include { xlsx_to_tsv; stitch; post_process; rename } from './workflows/PE_stitch'

/*
    Convert image exported tiles to ome zarr using bioformats2raw
*/
process Tiles_to_ome_zarr {
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
    if (hardware == 'nemo1'){
        stem = file(ome_index).baseName
    } else {
        stem = file(mea_folder).baseName
    }
    """
    /usr/local/bin/_entrypoint.sh bioformats2raw -w ${camera_dim} -h ${camera_dim} $mea_folder/${ome_index} "${stem}.zarr"
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
    ashlar -c ${ref_ch} $ome_tifs -m ${max_shift} --flip-y -o "${out_name}"
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

// update the channel names in the OME-TIFF using the channel names in the companion OME-XML or the embedded OME-XML
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

    /*label "default"*/
    /*cpus 5*/
    /*memory 300.Gb*/
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

    /*label "default"*/
    /*cpus 5*/
    /*memory 100.Gb*/
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
    xlsx_to_tsv(channel.from(
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

workflow PE_HCS {
    Generate_companion_ome(PE_STITCH())
}

workflow PE_WSI{
    post_process(PE_STITCH())
    rename(post_process.collect())
}

// use ashlar to stitch images from PE
workflow ashlar {
    /*_metadata_parsing()*/
    /*_metadata_parsing.out.view()*/
    params.meas_dirs = [["/nfs/team283_imaging/0HarmonyExports/LY_BRC/LY_BRC_AT0002__2022-10-07T17_43_01-Measurement 17/"]]
    hardware = "phenix"
    image_size = 2160
    Tiles_to_ome_zarr(channel.from(params.meas_dirs), params.index_file, [hardware, image_size])
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

workflow run_two_step_recon {
    params.input = [
        /*[['id':'test'], '/nfs/team283_imaging/Nemo2_data/FLNG_ISS/2022_11_08/C48/Cycle_1/Cam1_2/Cam1_2_MMStack_Cycle_1-Grid_0_1.ome.tif'],*/
        [['id':'test'], '/nfs/team283_imaging/Nemo2_data/FLNG_ISS/2022_11_08/HSTS/Cycle_1/Cam2_1/Cam2_1_MMStack_Pos0.ome.tif'],
    ]
    to_deconvolve = channel.from(params.input)
        .map{it -> [it[0], file(it[1], checkIfExists:true).getParent(), file(it[1]).getName()]}
    two_step_recon(to_deconvolve)
}
