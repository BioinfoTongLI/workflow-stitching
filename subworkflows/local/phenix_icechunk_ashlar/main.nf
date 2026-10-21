include { PHENIXICECHUNK } from "../../../modules/sanger-cellgeni/phenixicechunk"
include { ASHLAR         } from "../../../modules/nf-core/ashlar"

workflow PHENIX_ICECHUNK_ASHLAR {
    take:
    measurements_ch // channel: [ val(meta), path(image_dir), val(index_name) ], meta: [ id, round_index ]
    dfp_folder
    ffp_folder

    main:
    // One repo per measurement: make meta.id unique per round and keep the original id
    // as meta.sample to group the rounds back together for stitching
    measurements = measurements_ch.map { meta, image_dir, index_name ->
        [meta + [id: "${meta.id}_r${meta.round_index}".toString(), sample: meta.id], image_dir, index_name]
    }
    // Ashlar needs z projected fields: the conversion writes per-well max projection
    // OME-TIFFs (`--zproject max --ome-tiff .`, see conf/module.config)
    PHENIXICECHUNK(measurements)

    // Split per well and order each well's measurements by round_index, so ashlar
    // registers every later cycle against the first one
    cycles = PHENIXICECHUNK.out.ome_tiff
        .flatMap { meta, tiffs ->
            (tiffs instanceof List ? tiffs : [tiffs]).collect { tiff -> [meta, tiff] }
        }
        .map { meta, tiff ->
            // <plate>_<well>[_z<method>].ome.tiff
            def well = (tiff.name =~ /_([A-Z]+\d+)(?:_z[a-z]+)?\.ome\.tiff$/)[0][1]
            [[id: "${meta.sample}_${well}".toString(), sample: meta.sample, well: well], meta.round_index as Integer, tiff]
        }
        .groupTuple(by: 0)
        .map { meta, rounds, tiffs ->
            def ordered = [rounds, tiffs].transpose().sort { a, b -> a[0] <=> b[0] }
            [meta, ordered.collect { round_tiff -> round_tiff[1] }]
        }

    ASHLAR(cycles, dfp_folder, ffp_folder)

    emit:
    repo     = PHENIXICECHUNK.out.repo // channel: [ val(meta), path(repo.icechunk) ], one per measurement
    cycles   = cycles // channel: [ val(meta), [ path(ome.tiff) ] ], one per well, ordered by round_index
    stitched = ASHLAR.out.tif // channel: [ val(meta), path(ome.tif) ], one per well, all rounds registered
}
