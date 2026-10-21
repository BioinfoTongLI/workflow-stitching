include { ASHLAR } from '../modules/nf-core/ashlar/main'

workflow ASHLAR_RUN {
    take:
    images
    dfp_folder
    ffp_folder

    main:
    ASHLAR(images, dfp_folder, ffp_folder)

    emit:
    stitched = ASHLAR.out.tif // channel: [ val(meta), path(ome.tif) ]
}
