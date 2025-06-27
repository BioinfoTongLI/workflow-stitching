include { ASHLAR } from '../modules/nf-core/ashlar/main'
include { PREPROCESS_TILES } from '../subworkflows/sanger/preprocess_tiles/main'
include { IMAGING_ASHLARCOMPANION } from '../modules/sanger/imaging/ashlarcompanion/main'
include { IMAGING_PARSEMANIFEST } from '../modules/sanger/imaging/parsemanifest/main'

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

workflow PREPROCESS_TILES_ASHLAR_STITCH {
    take:
    images_ch // channel: [ val(meta), [ imaging_experiment ] ]
    dfp_folder
    ffp_folder
    psf_folder

    main:
    PREPROCESS_TILES(images_ch, psf_folder)
    multi_cycle_images = PREPROCESS_TILES.out.companion_tiles
        .groupTuple(by: 0)
        .map { meta, companions, images ->
            def sorted_companions = companions.sort { a, b ->
                def num_a = (a =~ /image(\d+)/)[0][1] as Integer
                def num_b = (b =~ /image(\d+)/)[0][1] as Integer
                num_a <=> num_b
            }
            [meta, sorted_companions, images.flatten().unique()]
        }

    IMAGING_ASHLARCOMPANION(
        multi_cycle_images,
        dfp_folder,
        ffp_folder,
        params.is_plate ?: false,
    )

    emit:
    IMAGING_ASHLARCOMPANION.out.tif
}
