include { ASHLAR } from '../modules/nf-core/ashlar/main'
include { PREPROCESS_TILES } from '../subworkflows/sanger-cellgeni/preprocess_tiles/main'
include { IMAGING_ASHLARCOMPANION } from '../modules/sanger-cellgeni/imaging/ashlarcompanion/main'
include { IMAGING_PARSEMANIFEST } from '../modules/sanger-cellgeni/imaging/parsemanifest/main'
include { IMAGING_GENERATECOMPANIONFROMFILES } from '../modules/sanger-cellgeni/imaging/generatecompanionfromfiles/main'
include { BIOFORMATS2RAWCOMPANION as BF2RAW_FINAL ; BIOFORMATS2RAWCOMPANION as BF2RAW_INIT } from '../modules/sanger-cellgeni/bioformats2rawcompanion/main'
include { PREPROCESS_OME_ZARR_TILES } from '../subworkflows/sanger-cellgeni/preprocess_ome_zarr_tiles/main'

params.is_plate = null

workflow ASHLAR_RUN {
    take:
    images
    dfp_folder
    ffp_folder

    main:
    ASHLAR(images, dfp_folder, ffp_folder)

    emit:
    ASHLAR.out.tif
}

workflow PREPROCESS_OME_ZARR_TILES_ASHLAR_STITCH {
    take:
    images_ch // channel: [ val(meta), val(round_index), [ imaging_experiment ] ]
    dfp_folder
    ffp_folder
    psf_folder

    main:
    BF2RAW_INIT(images_ch)

    PREPROCESS_OME_ZARR_TILES(
        BF2RAW_INIT.out.ome_zarr.map { meta, zarr -> [meta, meta.round_index, zarr, null] },
        psf_folder,
    )
    multi_cycle_images = PREPROCESS_OME_ZARR_TILES.out.companion_tiles
        .map { meta, companions, image ->
            def newMeta = meta.clone()
            newMeta.remove('round_index')
            [newMeta, companions, image]
        }
        .groupTuple(by: 0)
        .map { meta, companions, images ->
            def sorted_companions = companions.sort { a, b ->
                def num_a = (a =~ /image(\d+)/)[0][1] as Integer
                def num_b = (b =~ /image(\d+)/)[0][1] as Integer
                num_a <=> num_b
            }
            [meta, sorted_companions, images.flatten().unique()]
        }
    // multi_cycle_images.view()
    IMAGING_ASHLARCOMPANION(
        multi_cycle_images,
        dfp_folder,
        ffp_folder,
        params.is_plate ?: false,
    )

    IMAGING_GENERATECOMPANIONFROMFILES(
        IMAGING_ASHLARCOMPANION.out.tif.combine(channel.of(["*.ome.tif"]))
    )

    ch_to_ome_zarr = IMAGING_GENERATECOMPANIONFROMFILES.out.companion.combine(IMAGING_ASHLARCOMPANION.out.tif, by: 0)

    emit:
    companion = IMAGING_GENERATECOMPANIONFROMFILES.out.companion
}
