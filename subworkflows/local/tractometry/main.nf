include { TRACTOGRAM_REMOVEINVALID    } from '../../../modules/nf-neuro/tractogram/removeinvalid/main'
include { BUNDLE_FIXELAFD             } from '../../../modules/nf-neuro/bundle/fixelafd/main'
include { BUNDLE_CENTROID             } from '../../../modules/nf-neuro/bundle/centroid/main'
include { TRACTOGRAM_RESAMPLE         } from '../../../modules/nf-neuro/tractogram/resample/main'
include { BUNDLE_LABELMAP             } from '../../../modules/nf-neuro/bundle/labelmap/main'
include { BUNDLE_UNIFORMIZE           } from '../../../modules/nf-neuro/bundle/uniformize/main'
include { BUNDLE_STATS                } from '../../../modules/nf-neuro/bundle/stats/main'

workflow TRACTOMETRY {

    take:
        ch_bundles          // channel: [ val(meta), [ bundles ] ]
        ch_metrics          // channel: [ val(meta), [ metrics ] ]
        ch_lesion_mask      // channel: [ val(meta), lesions ]
        ch_fodf             // channel: [ val(meta), fodf ]

    main:

    ch_versions = Channel.empty()

    // ** Remove invalid streamlines ** //
    TRACTOGRAM_REMOVEINVALID ( ch_bundles )
    ch_versions = ch_versions.mix(TRACTOGRAM_REMOVEINVALID.out.versions)

    // ** Run AFD Fixel on the cleaned bundles. ** //
    ch_fixel = TRACTOGRAM_REMOVEINVALID.out.tractograms.join( ch_fodf )

    BUNDLE_FIXELAFD ( ch_fixel )
    ch_versions = ch_versions.mix(BUNDLE_FIXELAFD.out.versions)

    // ** Append the fixel afd to the existing metric channel ** //
    ch_metrics = ch_metrics.mix(BUNDLE_FIXELAFD.out.fixel_afd)
        .groupTuple(by: 0) // [ meta, [ metrics ] ]
        .map{ meta, metrics -> [ meta, metrics.flatten() ]}

    // ** Compute the centroids ** //
    BUNDLE_CENTROID( TRACTOGRAM_REMOVEINVALID.out.tractograms )
    ch_versions = ch_versions.mix(BUNDLE_CENTROID.out.versions)

    // ** Compute label maps and uniformize the bundles ** //
    ch_label_map = TRACTOGRAM_REMOVEINVALID.out.tractograms
        .join( BUNDLE_CENTROID.out.centroids )

    BUNDLE_LABELMAP ( ch_label_map )
    ch_versions = ch_versions.mix(BUNDLE_LABELMAP.out.versions)

    ch_label_trk = BUNDLE_LABELMAP.out.labels_trk
        .join( BUNDLE_CENTROID.out.centroids )

    BUNDLE_UNIFORMIZE ( ch_label_trk )
    ch_versions = ch_versions.mix(BUNDLE_UNIFORMIZE.out.versions)

    // ** Compute the statistics per bundle ** //
    ch_stats = BUNDLE_UNIFORMIZE.out.bundles
        .join( BUNDLE_LABELMAP.out.labels )
        .join( ch_metrics )
        .join( ch_lesion_mask, remainder: true )
        .map { [ it[0], it[1], it[2], it[3], it[4] ?: [] ] } // [ meta, bundle, metrics, lesion_mask ]

    BUNDLE_STATS ( ch_stats )
    ch_versions = ch_versions.mix(BUNDLE_STATS.out.versions)

    emit:
    length                      = BUNDLE_STATS.out.length ?: Channel.empty() // channel: [ val(meta), [ length_stats ] ]
    endpoints_raw               = BUNDLE_STATS.out.endpoints_raw ?: Channel.empty() // channel: [ val(meta), [ endpoints_raw ] ]
    endpoints_metric            = BUNDLE_STATS.out.endpoints_raw ?: Channel.empty() // channel: [ val(meta), [ endpoints_raw ] ]
    mean_std                    = BUNDLE_STATS.out.mean_std ?: Channel.empty()
    volume                      = BUNDLE_STATS.out.volume ?: Channel.empty()
    volume_lesions              = BUNDLE_STATS.out.volume_lesions ?: Channel.empty()
    streamline_count            = BUNDLE_STATS.out.streamline_count ?: Channel.empty()
    streamline_count_lesions    = BUNDLE_STATS.out.streamline_count_lesions ?: Channel.empty()
    volume_per_labels           = BUNDLE_STATS.out.volume_per_labels ?: Channel.empty()
    volume_per_labels_lesions   = BUNDLE_STATS.out.volume_per_labels_lesions ?: Channel.empty()
    mean_std_per_point          = BUNDLE_STATS.out.mean_std_per_point ?: Channel.empty()
    lesion_stats                = BUNDLE_STATS.out.lesion_stats ?: Channel.empty()
    endpoints_head              = BUNDLE_STATS.out.endpoints_head ?: Channel.empty()
    endpoints_tail              = BUNDLE_STATS.out.endpoints_tail ?: Channel.empty()
    lesion_map                  = BUNDLE_STATS.out.lesion_map ?: Channel.empty()

    versions = ch_versions                     // channel: [ versions.yml ]
}
