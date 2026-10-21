include { ASHLAR_RUN                 } from './workflows/main'
include { PREPROCESS_PHENIX_ICECHUNK } from './subworkflows/sanger-cellgeni/preprocess_phenix_icechunk'
include { PHENIX_ICECHUNK_ASHLAR     } from './subworkflows/local/phenix_icechunk_ashlar'

// manifest master_file points at the Harmony Index.xml of each measurement
def phenixMeasurements(manifest) {
    return channel.fromPath(manifest)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            def index_xml = file(row.master_file, checkIfExists: true)
            [
                [id: row.id, round_index: row.round_index],
                index_xml.parent,
                index_xml.name,
            ]
        }
}

workflow {
    main:
    // Every entry publishes to the same targets, see the output block below
    ch_icechunk = channel.empty()
    ch_stitched = channel.empty()
    ch_qc       = channel.empty()

    if (params.entry == 'phenix_icechunk_stitch') {
        PREPROCESS_PHENIX_ICECHUNK(phenixMeasurements(params.manifest))
        ch_icechunk = PREPROCESS_PHENIX_ICECHUNK.out.repo
        // The per-well ome.zarr are not published, their pixels are copied into the plate
        ch_stitched = PREPROCESS_PHENIX_ICECHUNK.out.plate
        ch_qc       = PREPROCESS_PHENIX_ICECHUNK.out.qc
    }
    else if (params.entry == 'phenix_icechunk_ashlar') {
        PHENIX_ICECHUNK_ASHLAR(phenixMeasurements(params.manifest), params.dfp_folder, params.ffp_folder)
        ch_icechunk = PHENIX_ICECHUNK_ASHLAR.out.repo
            .mix(PHENIX_ICECHUNK_ASHLAR.out.summary)
        ch_stitched = PHENIX_ICECHUNK_ASHLAR.out.stitched
    }
    else {
        images = channel.fromPath(params.manifest)
            .splitCsv(header: true, sep: ',')
            .map { row ->
                [
                    ['id': row.id],
                    file(row.master_file, checkIfExists: true),
                ]
            }
        ASHLAR_RUN(images, params.dfp_folder, params.ffp_folder)
        ch_stitched = ASHLAR_RUN.out.stitched
    }

    publish:
    icechunk = ch_icechunk
    stitched = ch_stitched
    qc       = ch_qc
}

// Published under outputDir (params.out_dir, see nextflow.config)
output {
    // converted icechunk repos and their summaries, one per measurement
    icechunk {
        path 'icechunk'
    }
    // final stitched images: ashlar OME-TIFFs or the stitched HCS plate
    stitched {
        path 'stitched'
    }
    // per-well stitching QC plots
    qc {
        path 'qc'
    }
}
