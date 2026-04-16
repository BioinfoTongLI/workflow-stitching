include { ASHLAR_RUN ; PREPROCESS_OME_ZARR_TILES_ASHLAR_STITCH } from './workflows/main'
include { IMAGING_ASHLARCOMPANION } from './modules/sanger-cellgeni/imaging/ashlarcompanion/main'
include { PE2OMETIF } from './modules/sanger-cellgeni/pe2ometif/main'
include { IMAGING_GENERATECOMPANIONFROMFILES } from './modules/sanger-cellgeni/imaging/generatecompanionfromfiles/main'

params.manifest = null
params.dfp_folder = []
params.ffp_folder = []
params.psf_folder = []
params.is_plate = null

workflow {
    images = channel.fromPath(params.manifest)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            [
                ['id': row.id],
                file(row.master_file, checkIfExists: true),
            ]
        }
    ASHLAR_RUN(images, params.dfp_folder, params.ffp_folder)
}

workflow PREPROCESS_OME_ZARR_TILES_ASHLAR {
    images_ch = channel.fromPath(params.manifest)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            [
                [id: row.id, round_index: row.round_index as Integer],
                file(row.master_file, checkIfExists: true),
                file(file(row.master_file, checkIfExists: true).parent + "/*tiff", checkIfExists: true),
            ]
        }

    PE2OMETIF(
        images_ch.map { meta, master, _images ->
            [meta, master.parent, master.name]
        }
    )

    multi_cycle_images = PE2OMETIF.out.companion
        .join(PE2OMETIF.out.ome_tif)
        .map { meta, companion, images ->
            [[id: meta.id], meta.round_index, companion, images]
        }
        .groupTuple(by: 0)
        .map { meta, round_indices, companions, images_list ->
            def sorted = [round_indices, companions, images_list]
                .transpose()
                .sort { a, b -> a[0] <=> b[0] }
            [[id: meta.id, round_index: meta.round_index], sorted.collect { row -> row[1] }, sorted.collect { row -> row[2] }.flatten()]
        }
    IMAGING_ASHLARCOMPANION(
        multi_cycle_images,
        params.dfp_folder,
        params.ffp_folder,
        params.is_plate ?: false,
    )
    IMAGING_GENERATECOMPANIONFROMFILES(
        IMAGING_ASHLARCOMPANION.out.tif.combine(channel.of(["*.ome.tif"]))
    )
}
