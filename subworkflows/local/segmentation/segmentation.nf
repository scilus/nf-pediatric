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
    ch_coreg        // channel: [ val(meta), [ t1 ] ]
    ch_fs_license   // channel: [ fs_license ]
    ch_utils_folder // channel: [ utils_folder ]

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Run FastSurfer or FreeSurfer T1 reconstruction
    //
    ch_seg = ch_t1
        .combine(ch_fs_license)
        .branch {
            fastsurfer: it[0].age >= 2.5 && it[0].age <= 18 && params.use_fastsurfer
                return it
            freesurfer: it[0].age >= 2.5 && it[0].age <= 18 && !params.use_fastsurfer
                return it
            infant: true
                return [it[0], it[1]]
        }

    // ** FastSurfer ** //
    FASTSURFER ( ch_seg.fastsurfer )
    ch_versions = ch_versions.mix(FASTSURFER.out.versions.first())

    // ** ReconAll ** //
    RECONALL ( ch_seg.freesurfer )
    ch_versions = ch_versions.mix(RECONALL.out.versions.first())

    // ** For infant, it's a bit trickier, as MCRIBS do not  ** //
    // ** perform preprocessing, so we need to do it (done in pediatric.nf).   ** //
    // ** Assuming the input channels are properly formatted ** //
    ch_t2w = ch_t2.branch {
        infant: it[0].age < 2.5 || it[0].age > 18
            return it
    }

    // ** Run MCRIBS ** //
    ch_mcribs = ch_t2w.infant
        .combine(ch_fs_license)
        .join(ch_coreg, remainder: true)
        .map { it[0..2] + [ it[3] ?: [] ] }

    MCRIBS ( ch_mcribs )
    ch_versions = ch_versions.mix(MCRIBS.out.versions.first())
    // ch_multiqc_files = ch_multiqc_files.mix(MCRIBS.out.zip.collect{it[1]})

    //
    // MODULE: Run BrainnetomeChild atlas
    //
    ch_atlas = Channel.empty()
        .mix(FASTSURFER.out.fastsurferdirectory)
        .mix(RECONALL.out.recon_all_out_folder)
        .mix(MCRIBS.out.folder)
        .groupTuple()
        .map {
            meta, files ->
                return [meta] + files.flatten().findAll { it != null }
        }
        .combine(ch_utils_folder)
        .combine(ch_fs_license)
        .branch {
            infant: it[0].age < 2.5 || it[0].age > 18
                return it
            child: it[0].age >= 2.5 && it[0].age <= 18
        }

    BRAINNETOMECHILD ( ch_atlas.child )
    ch_versions = ch_versions.mix(BRAINNETOMECHILD.out.versions.first())

    //
    // MODULE: Format labels
    //
    FORMATLABELS ( ch_atlas.infant )
    ch_versions = ch_versions.mix(FORMATLABELS.out.versions.first())

    ch_labels = Channel.empty()
        .mix(BRAINNETOMECHILD.out.labels)
        .mix(FORMATLABELS.out.labels)

    //
    // MODULE: Concatenate stats
    //
    ch_stats = Channel.empty()
        .mix(FORMATLABELS.out.stats.collect().map {
            [[id: 'Global', agegroup: 'Infant'], it]
        })
        .mix(BRAINNETOMECHILD.out.stats.collect().map{
            [[id: 'Global', agegroup: 'Child'], it]
        })

    CONCATENATESTATS ( ch_stats )
    ch_versions = ch_versions.mix(CONCATENATESTATS.out.versions)

    emit:
    // ** Processed anatomical image ** //
    t1              = ch_t1                                                 // channel: [ val(meta), [ t1 ] ]
    t2              = ch_t2                                                 // channel: [ val(meta), [ t2 ] ]

    // ** Segmentation ** //
    labels          = ch_labels                                             // channel: [ val(meta), [ labels ] ]
    tissues         = MCRIBS.out.aseg_presurf                               // channel: [ val(meta), [ tissues ] ]

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

