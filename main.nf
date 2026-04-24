include { ASHLAR_RUN } from './workflows/main'
include { IMAGING_ASHLARCOMPANION } from './modules/sanger-cellgeni/imaging/ashlarcompanion/main'
include { PE2OMETIF } from './modules/sanger-cellgeni/pe2ometif/main'
include { IMAGING_GENERATECOMPANIONFROMFILES } from './modules/sanger-cellgeni/imaging/generatecompanionfromfiles/main'
include { PREPROCESS_TIFF_TILES_ASHLAR } from './subworkflows/sanger-cellgeni/preprocess_tiff_tiles_ashlar/main'

params.manifest = null
params.dfp_folder = []
params.ffp_folder = []
params.psf_folder = []
params.is_plate = null

workflow RUN_ASHLAR {
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


workflow {
    images_ch = channel.fromPath(params.manifest)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            [
                [id: row.id, round_index: row.round_index as Integer],
                file(file(row.master_file, checkIfExists: true).parent),
                file(row.master_file, checkIfExists: true).name,
            ]
        }

    PREPROCESS_TIFF_TILES_ASHLAR(
        images_ch,
        params.dfp_folder ?: [],
        params.ffp_folder ?: [],
        params.is_plate ?: false,
    )
}
