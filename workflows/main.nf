include { ASHLAR } from '../modules/nf-core/ashlar/main'
include { PREPROCESS_TILES } from '../subworkflows/sanger-cellgeni/preprocess_tiles/main'
include { IMAGING_ASHLARCOMPANION } from '../modules/sanger-cellgeni/imaging/ashlarcompanion/main'
include { IMAGING_PARSEMANIFEST } from '../modules/sanger-cellgeni/imaging/parsemanifest/main'
include { IMAGING_GENERATECOMPANIONFROMFILES } from '../modules/sanger-cellgeni/imaging/generatecompanionfromfiles/main'
include { BIOFORMATS2RAWCOMPANION as BF2RAW_FINAL ; BIOFORMATS2RAWCOMPANION as BF2RAW_INIT } from '../modules/sanger-cellgeni/bioformats2rawcompanion/main'

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
