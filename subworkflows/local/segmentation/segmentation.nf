// ** Main segmentation module ** //
include { SEGMENTATION_FASTSURFER as FASTSURFER } from '../../../modules/nf-neuro/segmentation/fastsurfer/main'
include { SEGMENTATION_FSRECONALL as RECONALL } from '../../../modules/nf-neuro/segmentation/fsreconall/main'
include { SEGMENTATION_MCRIBS as MCRIBS } from '../../../modules/local/segmentation/mcribs'

// ** Atlas modules ** //
include { ATLASES_BRAINNETOMECHILD as BRAINNETOMECHILD } from '../../../modules/local/atlases/brainnetomechild'
include { ATLASES_FORMATLABELS as FORMATLABELS         } from '../../../modules/local/atlases/formatlabels'
include { ATLASES_CONCATENATESTATS as CONCATENATESTATS } from '../../../modules/local/atlases/concatenatestats'

// ** Utilities ** //
include { PREPROC_T1 as PREPROC_T1W } from '../../../subworkflows/nf-neuro/preproc_t1/main'
include { PREPROC_T1 as PREPROC_T2W } from '../../../subworkflows/nf-neuro/preproc_t1/main'
include { REGISTRATION_ANTS as COREG } from '../../../modules/nf-neuro/registration/ants/main'
include { imNotification } from '../../nf-core/utils_nfcore_pipeline/main.nf'

workflow SEGMENTATION {

    take:
    ch_t1           // channel: [ val(meta), [ t1 ] ]
    ch_t2           // channel: [ val(meta), [ t2 ] ]
    ch_fs_license   // channel: [ fs_license ]
    ch_utils_folder // channel: [ utils_folder ]
    weights      // channel: [ weights ]

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Run FastSurfer or FreeSurfer T1 reconstruction
    //
    ch_freesurfer = ch_t1.combine(ch_fs_license)

    if ( params.use_fastsurfer && !params.infant ) {

        // ** FastSurfer ** //
        FASTSURFER (ch_freesurfer)
        ch_versions = ch_versions.mix(FASTSURFER.out.versions.first())

        // ** Setting outputs ** //
        ch_folder = FASTSURFER.out.fastsurferdirectory
        ch_t1 = FASTSURFER.out.final_t1
        ch_t2 = Channel.empty()
        ch_tissueseg = Channel.empty()

    } else if ( params.infant ) {

        // ** For infant, it's a bit trickier, as MCRIBS do not  ** //
        // ** perform preprocessing, so we need to do it here.   ** //
        // ** Assuming the input channels are properly formatted ** //
        PREPROC_T1W (
            ch_t1,
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            weights
        )
        ch_versions = ch_versions.mix(PREPROC_T1W.out.versions.first())

        PREPROC_T2W (
            ch_t2,
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            weights
        )
        ch_versions = ch_versions.mix(PREPROC_T2W.out.versions.first())

        // ** Register T1 to T2 if T1 is provided ** //
        ch_reg = PREPROC_T2W.out.t1_final
            .join(PREPROC_T1W.out.t1_final, remainder: true)
            .branch {
                witht1: it.size() > 2 && it[2] != null
                    return [ it[0], it[1], it[2], [] ]
            }

        COREG ( ch_reg.witht1 )
        ch_versions = ch_versions.mix(COREG.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(COREG.out.zip.collect{it[1]})

        // ** Run MCRIBS ** //
        ch_mcribs = PREPROC_T2W.out.t1_final
            .combine(ch_fs_license)
            .join(COREG.out.image, remainder: true)
            .map { it[0..2] + [ it[3] ?: [] ] }

        MCRIBS ( ch_mcribs )
        ch_versions = ch_versions.mix(MCRIBS.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(MCRIBS.out.zip.collect{it[1]})

        // ** Setting outputs ** //
        ch_folder = MCRIBS.out.folder
        ch_t1 = PREPROC_T1W.out.t1_final
        ch_t2 = PREPROC_T2W.out.t1_final
        ch_tissueseg = MCRIBS.out.aseg_presurf

    } else {
        // ** FreeSurfer ** //
        RECONALL (ch_freesurfer)
        ch_versions = ch_versions.mix(RECONALL.out.versions.first())

        // ** Setting outputs ** //
        ch_folder = RECONALL.out.recon_all_out_folder
        ch_t1 = RECONALL.out.final_t1
        ch_t2 = Channel.empty()
        ch_tissueseg = Channel.empty()
    }

    //
    // MODULE: Run BrainnetomeChild atlas
    //
    ch_atlas = ch_folder
        .combine(ch_utils_folder)
        .combine(ch_fs_license)
        .branch {
            infant: params.infant
                return [ it[0], it[1], it[2], it[3] ]
            children: true
                return [ it[0], it[1], it[2], it[3] ]
        }

    BRAINNETOMECHILD ( ch_atlas.children )
    ch_versions = ch_versions.mix(BRAINNETOMECHILD.out.versions.first())

    //
    // MODULE: Format labels
    //
    FORMATLABELS ( ch_atlas.infant )
    ch_versions = ch_versions.mix(FORMATLABELS.out.versions.first())

    //
    // MODULE: Concatenate stats
    //
    CONCATENATESTATS ( params.infant ? FORMATLABELS.out.stats.collect() : BRAINNETOMECHILD.out.stats.collect() )
    ch_versions = ch_versions.mix(CONCATENATESTATS.out.versions)

    emit:
    // ** Processed anatomical image ** //
    t1              = ch_t1                                                 // channel: [ val(meta), [ t1 ] ]
    t2              = ch_t2                                                 // channel: [ val(meta), [ t2 ] ]

    // ** Segmentation ** //
    labels          = params.infant ? FORMATLABELS.out.labels : BRAINNETOMECHILD.out.labels // channel: [ val(meta), [ labels ] ]
    tissues         = ch_tissueseg                                                          // channel: [ val(meta), [ tissues ] ]

    // ** Stats ** //
    volume_lh       = CONCATENATESTATS.out.volume_lh ?: Channel.empty()     // channel: [ volume_lh.tsv ]
    volume_rh       = CONCATENATESTATS.out.volume_rh ?: Channel.empty()     // channel: [ volume_rh.tsv ]
    area_lh         = CONCATENATESTATS.out.area_lh ?: Channel.empty()       // channel: [ area_lh.tsv ]
    area_rh         = CONCATENATESTATS.out.area_rh ?: Channel.empty()       // channel: [ area_rh.tsv ]
    thickness_lh    = CONCATENATESTATS.out.thickness_lh ?: Channel.empty()  // channel: [ thickness_lh.tsv ]
    thickness_rh    = CONCATENATESTATS.out.thickness_rh ?: Channel.empty()  // channel: [ thickness_rh.tsv ]
    subcortical     = CONCATENATESTATS.out.subcortical ?: Channel.empty()   // channel: [ subcortical_volumes.tsv ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

