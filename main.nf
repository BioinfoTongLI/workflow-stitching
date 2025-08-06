include { ASHLAR_RUN ; PREPROCESS_TILES_ASHLAR_STITCH } from './workflows/main'

params.manifest = "/home/ubuntu/Documents/workflow-stitching/manifest.csv"
params.dfp_folder = []
params.ffp_folder = []
params.psf_folder = []

workflow {
    images = channel
        .fromPath(params.manifest)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            [
                ['id': row.id],
                file(row.master_file, checkIfExists: true),
            ]
        }
    ASHLAR_RUN(images, params.dfp_folder, params.ffp_folder)
}

workflow PREPROCESS_TILES_ASHLAR {
    images = channel
        .fromPath(params.manifest)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            [
                ['id': row.id],
                row.round,
                file(row.master_file, checkIfExists: true).parent,
                file(row.master_file, checkIfExists: true).name,
            ]
        }
    PREPROCESS_TILES_ASHLAR_STITCH(
        images,
        params.dfp_folder,
        params.ffp_folder,
        params.psf_folder,
    )
}
