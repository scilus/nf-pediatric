include { SEGMENTATION_FASTSURFER as FASTSURFER } from '../../../modules/nf-neuro/segmentation/fastsurfer/main'
include { SEGMENTATION_FSRECONALL as RECONALL } from '../../../modules/nf-neuro/segmentation/fsreconall/main'
include { ATLASES_BRAINNETOMECHILD as BRAINNETOMECHILD } from '../../../modules/local/atlases/brainnetomechild'

workflow FREESURFERFLOW {

    take:
    ch_t1           // channel: [ val(meta), [ t1 ] ]
    ch_fs_license   // channel: [ fs_license ]
    ch_utils_folder // channel: [ utils_folder ]

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Run FastSurfer or FreeSurfer T1 reconstruction
    //
    ch_freesurfer = ch_t1.combine(ch_fs_license)

    if ( params.use_fastsurfer ) {
        FASTSURFER (ch_freesurfer)
        ch_versions = ch_versions.mix(FASTSURFER.out.versions.first())
        ch_folder = FASTSURFER.out.fastsurferdirectory
    } else {
        RECONALL (ch_freesurfer)
        ch_versions = ch_versions.mix(RECONALL.out.versions.first())
        ch_folder = RECONALL.out.recon_all_out_folder
    }

    //
    // MODULE: Run BrainnetomeChild atlas
    //
    ch_atlas = ch_folder.combine(ch_utils_folder).combine(ch_fs_license)

    BRAINNETOMECHILD (ch_atlas)
    ch_versions = ch_versions.mix(BRAINNETOMECHILD.out.versions.first())

    emit:
    labels   = BRAINNETOMECHILD.out.labels     // channel: [ val(meta), [ labels ] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

