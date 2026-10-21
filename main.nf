include { ASHLAR_RUN                 } from './workflows/main'
include { PREPROCESS_PHENIX_ICECHUNK } from './subworkflows/sanger-cellgeni/preprocess_phenix_icechunk'
include { PHENIX_ICECHUNK_ASHLAR     } from './subworkflows/local/phenix_icechunk_ashlar'

workflow {
    if (params.entry == 'phenix_icechunk_stitch') {
        // manifest master_file points at the Harmony Index.xml of each measurement
        measurements = channel.fromPath(params.manifest)
            .splitCsv(header: true, sep: ',')
            .map { row ->
                def index_xml = file(row.master_file, checkIfExists: true)
                [
                    [id: row.id, round_index: row.round_index],
                    index_xml.parent,
                    index_xml.name,
                ]
            }
        PREPROCESS_PHENIX_ICECHUNK(measurements)
    }
    else if (params.entry == 'phenix_icechunk_ashlar') {
        // manifest master_file points at the Harmony Index.xml of each measurement
        measurements = channel.fromPath(params.manifest)
            .splitCsv(header: true, sep: ',')
            .map { row ->
                def index_xml = file(row.master_file, checkIfExists: true)
                [
                    [id: row.id, round_index: row.round_index],
                    index_xml.parent,
                    index_xml.name,
                ]
            }
        PHENIX_ICECHUNK_ASHLAR(measurements, params.dfp_folder, params.ffp_folder)
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
    }
}
