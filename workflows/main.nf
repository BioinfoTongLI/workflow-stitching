
include { ASHLAR } from '../modules/nf-core/ashlar/main'
include { PREPROCESS_TILES } from '../subworkflows/sanger/preprocess_tiles/main'


workflow ASHLAR_RUN{
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
    ASHLAR(PREPROCESS_TILES.out.processed_tiles, dfp_folder, ffp_folder)

    emit:
    ASHLAR.out.tif
}