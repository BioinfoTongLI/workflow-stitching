#!/usr/bin/env/ nextflow

// Copyright (C) 2020 Tong LI <tongli.bioinfo@protonmail.com>

params.meas = "/nfs/team283_imaging/TL_SYN/iNeuron1__2020-03-12T16_05_45-Measurement_Test"
params.gap = 4000
params.out = "/nfs/team283_imaging/TL_SYN/meas_test"
params.z_mode = "max"

process stitch {
    echo true
    storeDir params.out
    container 'acapella-tong:1.1.7'
    containerOptions '--volume ' + params.meas + ':/data_in/:ro'
    /*input:*/
    /*path meas from Channel.fromPath(params.meas)*/

    output:
    path "*"

    script:
    base = file(params.meas).getName()
    """
    acapella -license /home/acapella/AcapellaLicense.txt -s IndexFile="/data_in/Images/Index.idx.xml" -s OutputDir="./" -s ZProjection="${params.z_mode}" -s OutputFormat=tiff -s Silent=false -s Channels="ALL" -s Gap=${params.gap} /home/acapella/StitchImage.script
    """
}
