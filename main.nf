include { ASHLAR_RUN; PREPROCESS_TILES_ASHLAR_STITCH } from './workflows/main'


params.images = [
    [
        ["id": "scilifelab"],
        [
            "/lustre/scratch127/cellgen/cellgeni/tickets/tic-3694/NBC_exp01/OME_tiffs/Base_1.ome.tiff",
            "/lustre/scratch127/cellgen/cellgeni/tickets/tic-3694/NBC_exp01/OME_tiffs/Base_2.ome.tiff",
            "/lustre/scratch127/cellgen/cellgeni/tickets/tic-3694/NBC_exp01/OME_tiffs/Base_3.ome.tiff",
            "/lustre/scratch127/cellgen/cellgeni/tickets/tic-3694/NBC_exp01/OME_tiffs/Base_4.ome.tiff",
            "/lustre/scratch127/cellgen/cellgeni/tickets/tic-3694/NBC_exp01/OME_tiffs/Base_5.ome.tiff",
        ]
    ],
]

workflow {
    ASHLAR_RUN(Channel.from(params.images), [], [])
}

workflow PREPROCESS_TILES_ASHLAR {
    PREPROCESS_TILES_ASHLAR_STITCH(
        Channel.from(params.images),
        "",
        "",
        "/lustre/scratch127/cellgen/cellgeni/projects/imaging_PSFs/",
    )
}