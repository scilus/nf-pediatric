include { SEGMENTATION_FASTSURFER as FASTSURFER } from '../../../modules/nf-neuro/segmentation/fastsurfer/main'
include { SEGMENTATION_FSRECONALL as RECONALL } from '../../../modules/nf-neuro/segmentation/fsreconall/main'
include { ATLASES_BRAINNETOMECHILD as BRAINNETOMECHILD } from '../../../modules/local/atlases/brainnetomechild'
include { ATLASES_CONCATENATESTATS as CONCATENATESTATS } from '../../../modules/local/atlases/concatenatestats'

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
        ch_t1 = FASTSURFER.out.final_t1
    } else {
        RECONALL (ch_freesurfer)
        ch_versions = ch_versions.mix(RECONALL.out.versions.first())
        ch_folder = RECONALL.out.recon_all_out_folder
        ch_t1 = RECONALL.out.final_t1
    }

    //
    // MODULE: Run BrainnetomeChild atlas
    //
    ch_atlas = ch_folder.combine(ch_utils_folder).combine(ch_fs_license)

    BRAINNETOMECHILD (ch_atlas)
    ch_versions = ch_versions.mix(BRAINNETOMECHILD.out.versions.first())

    //
    // MODULE: Concatenate stats
    //
    CONCATENATESTATS ( BRAINNETOMECHILD.out.stats.collect() )

    emit:
    t1       = ch_t1                           // channel: [ val(meta), [ t1 ] ]
    labels   = BRAINNETOMECHILD.out.labels     // channel: [ val(meta), [ labels ] ]

    volume_lh       = CONCATENATESTATS.out.volume_lh  // channel: [ volume_lh.tsv ]
    volume_rh       = CONCATENATESTATS.out.volume_rh  // channel: [ volume_rh.tsv ]
    area_lh         = CONCATENATESTATS.out.area_lh    // channel: [ area_lh.tsv ]
    area_rh         = CONCATENATESTATS.out.area_rh    // channel: [ area_rh.tsv ]
    thickness_lh    = CONCATENATESTATS.out.thickness_lh // channel: [ thickness_lh.tsv ]
    thickness_rh    = CONCATENATESTATS.out.thickness_rh // channel: [ thickness_rh.tsv ]
    subcortical     = CONCATENATESTATS.out.subcortical // channel: [ subcortical_volumes.tsv ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

