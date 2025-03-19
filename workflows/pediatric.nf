/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// ** Core modules ** //
include { MULTIQC as MULTIQC_SUBJECT        } from '../modules/nf-core/multiqc/main'
include { MULTIQC as MULTIQC_GLOBAL         } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                  } from 'plugin/nf-schema'
include { paramsSummaryMultiqc              } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML            } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText            } from '../subworkflows/local/utils_nfcore_nf-pediatric_pipeline'
include { FETCH_DERIVATIVES                 } from '../subworkflows/local/utils/fetch_derivatives.nf'

// ** Anatomical reconstruction ** //
include { SEGMENTATION                    } from '../subworkflows/local/segmentation/segmentation'

// ** Anatomical Preprocessing ** //
include { PREPROC_T1 as PREPROC_T1W         } from '../subworkflows/nf-neuro/preproc_t1/main'
include { PREPROC_T1 as PREPROC_T2W         } from '../subworkflows/nf-neuro/preproc_t1/main'
include { REGISTRATION_ANTS as COREG        } from '../modules/nf-neuro/registration/ants/main'

// ** DWI Preprocessing ** //
include { PREPROC_DWI                       } from '../subworkflows/nf-neuro/preproc_dwi/main'
include { IMAGE_RESAMPLE as RESAMPLE_DWI    } from '../modules/nf-neuro/image/resample/main'
include { BETCROP_CROPVOLUME as CROPDWI     } from '../modules/nf-neuro/betcrop/cropvolume/main'
include { UTILS_EXTRACTB0 as EXTRACTB0      } from '../modules/nf-neuro/utils/extractb0/main'

// ** DTI Metrics ** //
include { RECONST_DTIMETRICS                } from '../modules/nf-neuro/reconst/dtimetrics/main'

// ** FRF ** //
include { RECONST_FRF                       } from '../modules/nf-neuro/reconst/frf/main'
include { RECONST_MEANFRF                   } from '../modules/nf-neuro/reconst/meanfrf/main'

// ** FODF Metrics ** //
include { RECONST_FODF                      } from '../modules/nf-neuro/reconst/fodf/main'

// ** Registration ** //
include { REGISTRATION_ANATTODWI as ANATTODWI } from '../modules/nf-neuro/registration/anattodwi/main'
include { REGISTRATION_ANTSAPPLYTRANSFORMS as APPLYTRANSFORMS } from '../modules/nf-neuro/registration/antsapplytransforms/main'

// ** Anatomical Segmentation ** //
include { SEGMENTATION_FASTSEG as FASTSEG   } from '../modules/nf-neuro/segmentation/fastseg/main'
include { SEGMENTATION_MCRIBS as TISSUESEG  } from '../modules/local/segmentation/mcribs.nf'
include { SEGMENTATION_MASKS as MASKS       } from '../modules/local/segmentation/masks.nf'
include { REGISTRATION_ANTSAPPLYTRANSFORMS as TRANSFORMTISSUES } from '../modules/nf-neuro/registration/antsapplytransforms/main'

// ** Tracking ** //
include { TRACKING_PFTTRACKING              } from '../modules/nf-neuro/tracking/pfttracking/main'
include { TRACKING_LOCALTRACKING            } from '../modules/nf-neuro/tracking/localtracking/main'

// ** Connectomics ** //
include { REGISTRATION_ANTSAPPLYTRANSFORMS as TRANSFORM_LABELS } from '../modules/nf-neuro/registration/antsapplytransforms/main'
include { FILTERING_COMMIT                  } from '../modules/local/filtering/commit.nf'
include { CONNECTIVITY_DECOMPOSE            } from '../modules/nf-neuro/connectivity/decompose/main'
include { CONNECTIVITY_AFDFIXEL             } from '../modules/nf-neuro/connectivity/afdfixel/main'
include { CONNECTIVITY_METRICS              } from '../modules/local/connectivity/metrics.nf'
include { CONNECTIVITY_VISUALIZE            } from '../modules/nf-neuro/connectivity/visualize/main'

// ** Output in template space ** //
include { OUTPUT_TEMPLATE_SPACE             } from '../subworkflows/nf-neuro/output_template_space/main'

// ** QC ** //
include { QC } from '../subworkflows/local/QC/qc.nf'
include { imNotification } from '../subworkflows/nf-core/utils_nfcore_pipeline/main.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PEDIATRIC {

    take:
    ch_input_bids    // channel: from --input_bids

    main:

    // Empty channels to collect data during runtime
    ch_versions = Channel.empty()
    ch_multiqc_files_sub = Channel.empty()
    ch_nifti_files_to_transform = Channel.empty()
    ch_trk_files_to_transform = Channel.empty()

    //
    // Decomposing the samplesheet into individual channels
    //
    ch_inputs = ch_input_bids
        .multiMap{ meta, t1, t2, dwi, bval, bvec, rev_dwi, rev_bval, rev_bvec, rev_b0 ->
            t1: [meta, t1]
            t2: [meta, t2]
            dwi_bval_bvec: [meta, dwi, bval, bvec]
            rev_b0: [meta, rev_b0]
            rev_dwi_bval_bvec: [meta, rev_dwi, rev_bval, rev_bvec]
        }

    // ** Check if T1 is provided ** //
    ch_t1 = ch_inputs.t1
        .branch {
            witht1: it.size() > 1 && it[1] != []
                return [ it[0], it[1] ]
        }

    // ** Check if T2 is provided ** //
    ch_t2 = ch_inputs.t2
        .branch {
            witht2: it.size() > 1 && it[1] != []
                return [ it[0], it[1] ]
        }

    // ** Loading synthstrip alternative weights if provided ** //
    if ( params.t1_synthstrip_weights ) {
        ch_t1_weights = Channel.fromPath(params.t1_synthstrip_weights, checkIfExists: false)
    } else {
        ch_t1_weights = Channel.empty()
    }

    if ( params.t2_synthstrip_weights ) {
        ch_t2_weights = Channel.fromPath(params.t2_synthstrip_weights, checkIfExists: false)
    } else {
        ch_t2_weights = Channel.empty()
    }

    //
    // SUBWORKFLOW: Run FastSurfer or FreeSurfer T1 reconstruction with BrainnetomeChild atlas
    // Additionally, if infant data is provided, run MCRIBS segmentation.
    //
    if ( params.segmentation ) {

        // ** Fetch license file ** //
        ch_fs_license = params.fs_license
            ? Channel.fromPath(params.fs_license, checkIfExists: true, followLinks: true)
            : Channel.empty().ifEmpty { error "No license file path provided. Please specify the path using --fs_license parameter." }

        // ** Fetch utils folder ** //
        ch_utils_folder = Channel.fromPath(params.utils_folder, checkIfExists: true)

        SEGMENTATION (
            ch_t1.witht1,
            ch_t2.witht2,
            ch_fs_license,
            ch_utils_folder,
            ch_t1_weights,
            ch_t2_weights
        )

        ch_versions = ch_versions.mix(SEGMENTATION.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(FASTSURFER.out.zip.collect{it[1]})

    }

    //
    // SUBWORKFLOW: Run preprocessing on anatomical images.
    //
    if ( params.infant && params.tracking ) {
        ch_fs_license = params.fs_license
            ? Channel.fromPath(params.fs_license, checkIfExists: true, followLinks: true)
            : Channel.empty().ifEmpty { error "No license file path provided. Please specify the path using --fs_license parameter." }
        }

    reg_t1 = Channel.empty()

    if ( params.tracking && !params.segmentation ) {

        // ** Run T1 preprocessing ** //
        ch_meta = ch_t1.witht1.map{ it[0] }
        PREPROC_T1W (
            ch_t1.witht1,
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            ch_meta.combine(ch_t1_weights)
        )
        ch_versions = ch_versions.mix(PREPROC_T1W.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(PREPROC_T1.out.zip.collect{it[1]})

        // ** T2 Preprocessing ** //
        ch_meta_t2 = ch_t2.witht2.map{ it[0] }
        PREPROC_T2W (
            ch_t2.witht2,
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            ch_meta_t2.combine(ch_t2_weights)
        )
        ch_versions = ch_versions.mix(PREPROC_T2W.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(PREPROC_T2.out.zip.collect{it[1]})

        // ** Register T1 to T2 if T1 is provided ** //
        ch_reg = PREPROC_T2W.out.t1_final
            .join(PREPROC_T1W.out.t1_final, remainder: true)
            .branch {
                witht1: params.infant && it.size() > 2 && it[2] != null
                witht2: !params.infant && it.size() > 2 && it[1] != null
                other: true // Catch-all for any other cases
            }

        ch_reg.witht1
            .map { it -> [ it[0], it[1], it[2], [] ] }
            .mix(ch_reg.witht2.map { it -> [ it[0], it[2], it[1], [] ] })
            .set { ch_coreg_input }

        COREG ( ch_coreg_input )
        ch_versions = ch_versions.mix(COREG.out.versions)
        // ch_multiqc_files = ch_multiqc_files.mix(COREG.out.zip.collect{it[1]})
        reg_t1 = COREG.out.image ?: Channel.empty()
    }

    //
    // SUBWORKFLOW: Run PREPROC_DWI
    //
    if ( params.tracking ) {

        if ( !params.dti_shells ) { error "Please provide the DTI shells using --dti_shells parameter" }
        if ( !params.fodf_shells ) { error "Please provide the FODF shells using --fodf_shells parameter" }

        /* Load topup config if provided */
        if ( params.dwi_susceptibility_config_file ) {
            if ( file(params.dwi_susceptibility_config_file).exists() ) {
                ch_topup_config = Channel.fromPath(params.dwi_susceptibility_config_file, checkIfExists: true)
            }
            else {
                ch_topup_config = Channel.value( params.dwi_susceptibility_config_file )
            }
        }

        if ( params.dwi_synthstrip_weights ) {
            ch_dwi_weights = Channel.fromPath(params.dwi_synthstrip_weights, checkIfExists: false)
        } else {
            ch_dwi_weights = Channel.value([])
        }

        /* Run DWI preprocessing if the data isn't already preprocessed */
        /* else, just resample and crop the data                        */
        PREPROC_DWI(
            ch_inputs.dwi_bval_bvec,
            ch_inputs.rev_dwi_bval_bvec,
            Channel.empty(),
            ch_inputs.rev_b0,
            ch_topup_config,
            ch_dwi_weights
        )
        ch_versions = ch_versions.mix(PREPROC_DWI.out.versions)
        ch_multiqc_files_sub = ch_multiqc_files_sub.mix(PREPROC_DWI.out.mqc)

        // ** Setting outputs ** //
        ch_processed_dwi = PREPROC_DWI.out.dwi
        ch_processed_bval = PREPROC_DWI.out.bval
        ch_processed_bvec = PREPROC_DWI.out.bvec
        ch_processed_b0 = PREPROC_DWI.out.b0
        ch_processed_b0_mask = PREPROC_DWI.out.b0_mask

        //
        // MODULE: Run DTI_METRICS
        //
        ch_reconst_dti = ch_processed_dwi
            .join(ch_processed_bval)
            .join(ch_processed_bvec)
            .join(ch_processed_b0_mask)

        RECONST_DTIMETRICS ( ch_reconst_dti )
        ch_versions = ch_versions.mix(RECONST_DTIMETRICS.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(RECONST_DTIMETRICS.out.zip.collect{it[1]})
        ch_nifti_files_to_transform = ch_nifti_files_to_transform
            .mix(RECONST_DTIMETRICS.out.fa)
            .mix(RECONST_DTIMETRICS.out.md)
            .mix(RECONST_DTIMETRICS.out.ad)
            .mix(RECONST_DTIMETRICS.out.rd)
            .mix(RECONST_DTIMETRICS.out.ga)
            .mix(RECONST_DTIMETRICS.out.mode)
            .mix(RECONST_DTIMETRICS.out.rgb)

        //
        // MODULE: Run FRF
        //
        ch_reconst_frf = ch_processed_dwi
            .join(ch_processed_bval)
            .join(ch_processed_bvec)
            .join(ch_processed_b0_mask)
            .map{ it + [[], [], []] }

        RECONST_FRF ( ch_reconst_frf )
        ch_versions = ch_versions.mix(RECONST_FRF.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(RECONST_FRF.out.zip.collect{it[1]})

        //** Run FRF averaging if selected **//
        ch_frf = RECONST_FRF.out.frf
        if ( params.frf_mean_frf ) {

            RECONST_MEANFRF ( RECONST_FRF.out.frf.map{ it[1] }.flatten() )
            ch_versions = ch_versions.mix(RECONST_MEANFRF.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(RECONST_MEANFRF.out.zip.collect{it[1]})

            ch_frf = RECONST_FRF.out.map{ it[0] }
                .combine( RECONST_MEANFRF.out.meanfrf )
        }

        //
        // MODULE: Run MEANFRF
        //
        ch_reconst_fodf = ch_processed_dwi
            .join(ch_processed_bval)
            .join(ch_processed_bvec)
            .join(ch_processed_b0_mask)
            .join(RECONST_DTIMETRICS.out.fa)
            .join(RECONST_DTIMETRICS.out.md)
            .join(ch_frf)
            .map{ it + [[], []]}

        RECONST_FODF ( ch_reconst_fodf )
        ch_versions = ch_versions.mix(RECONST_FODF.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(RECONST_FODF.out.zip.collect{it[1]})
        ch_nifti_files_to_transform = ch_nifti_files_to_transform
            .mix(RECONST_FODF.out.afd_total)
            .mix(RECONST_FODF.out.nufo)
            .mix(RECONST_FODF.out.afd_max)
            .mix(RECONST_FODF.out.afd_sum)

        //
        // MODULE: Run REGISTRATION
        //
        if ( params.infant && params.segmentation ) {
            ch_anat_reg = SEGMENTATION.out.t2
                .join(ch_processed_b0)
                .join(RECONST_DTIMETRICS.out.md)
        } else if ( !params.infant && params.segmentation ) {
            ch_anat_reg = SEGMENTATION.out.t1
                .join(ch_processed_b0)
                .join(RECONST_DTIMETRICS.out.fa)
        } else if ( params.infant ) {
            ch_anat_reg = PREPROC_T2W.out.t1_final
                .join(ch_processed_b0)
                .join(RECONST_DTIMETRICS.out.md)
        } else {
            ch_anat_reg = PREPROC_T1W.out.t1_final
                .join(ch_processed_b0)
                .join(RECONST_DTIMETRICS.out.fa)
        }

        ANATTODWI( ch_anat_reg )
        ch_versions = ch_versions.mix(ANATTODWI.out.versions)
        ch_multiqc_files_sub = ch_multiqc_files_sub.mix(ANATTODWI.out.mqc)

        //
        // SUBWORKFLOW: Run ANATOMICAL_SEGMENTATION
        //
        if ( params.infant ) {

            // ** Apply transformation to the T1 image, if provided ** //
            ch_antsapply = Channel.empty()
            if ( reg_t1 || SEGMENTATION.out.t1 ) {
                t1_to_apply = params.segmentation ? SEGMENTATION.out.t1 : reg_t1
                ch_antsapply = t1_to_apply
                    .join(ANATTODWI.out.t1_warped)
                    .join(ANATTODWI.out.warp)
                    .join(ANATTODWI.out.affine)
                    .view()
            }

            APPLYTRANSFORMS ( ch_antsapply )
            ch_versions = ch_versions.mix(APPLYTRANSFORMS.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(APPLYTRANSFORMS.out.zip.collect{it[1]})

            // ** Run MCRIBS segmentation ** //
            ch_tissueseg_t2 = ANATTODWI.out.t1_warped
                .combine(ch_fs_license)
                .join(APPLYTRANSFORMS.out.warped_image, remainder: true)
                .map{ it[0..2] + [ it[3] ?: [] ] }

            TISSUESEG ( !params.segmentation ? ch_tissueseg_t2 : Channel.empty() )
            ch_versions = ch_versions.mix(TISSUESEG.out.versions.first())

            // ** Create WM, GM, and CSF masks from the MCRIBS segmentation   ** //
            // ** If complete segmentation has been run, apply transformation ** //
            // ** to the tissue segmentation masks.                           ** //
            if ( params.segmentation ) {
                // ** Apply transformation to the tissue segmentation ** //
                ch_apply_transform = SEGMENTATION.out.tissues
                    .join(ANATTODWI.out.t1_warped)
                    .join(ANATTODWI.out.warp)
                    .join(ANATTODWI.out.affine)

                TRANSFORMTISSUES ( ch_apply_transform )
                ch_versions = ch_versions.mix(TRANSFORMTISSUES.out.versions.first())
                // ch_multiqc_files = ch_multiqc_files.mix(TRANSFORMTISSUES.out.zip.collect{it[1]})

                ch_masking = TRANSFORMTISSUES.out.warped_image
                    .join(RECONST_DTIMETRICS.out.fa)
            } else {
                ch_masking = TISSUESEG.out.aseg_presurf
                    .join(RECONST_DTIMETRICS.out.fa)
            }

            // ** Generate WM, GM, and CSF masks ** //
            MASKS ( ch_masking )
            ch_versions = ch_versions.mix(MASKS.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(MASKS.out.zip.collect{it[1]})

            ch_wm_mask = MASKS.out.wm_mask

        } else {

            ch_fastseg = ANATTODWI.out.t1_warped
                .map { it + [[]] }

            FASTSEG ( ch_fastseg )
            ch_versions = ch_versions.mix(FASTSEG.out.versions)
            // ch_multiqc_files = ch_multiqc_files.mix(ANATOMICAL_SEGMENTATION.out.zip.collect{it[1]})

            ch_wm_mask = FASTSEG.out.wm_mask
        }

        //
        // MODULE: Run PFT_TRACKING
        //
        if ( params.run_pft_tracking ) {

            params.infant ? error( "PFT tracking is not implemented for infant data as of now, please use local tracking instead." ) : null

            ch_pft_tracking = FASTSEG.out.wm_map
                .join(FASTSEG.out.gm_map)
                .join(FASTSEG.out.csf_map)
                .join(RECONST_FODF.out.fodf)
                .join(RECONST_DTIMETRICS.out.fa)

            TRACKING_PFTTRACKING ( ch_pft_tracking )
            ch_versions = ch_versions.mix(TRACKING_PFTTRACKING.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(TRACKING_PFTTRACKING.out.zip.collect{it[1]})
            ch_trk_files_to_transform = ch_trk_files_to_transform
                .mix(TRACKING_PFTTRACKING.out.trk)

            ch_trk = TRACKING_PFTTRACKING.out.trk

        }
        //
        // MODULE: Run LOCAL_TRACKING
        //
        if ( params.run_local_tracking ) {

            ch_local_tracking = ch_wm_mask
                .join(RECONST_FODF.out.fodf)
                .join(RECONST_DTIMETRICS.out.fa)

            TRACKING_LOCALTRACKING ( ch_local_tracking )
            ch_versions = ch_versions.mix(TRACKING_LOCALTRACKING.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(TRACKING_LOCALTRACKING.out.zip.collect{it[1]})
            ch_trk_files_to_transform = ch_trk_files_to_transform
                .mix(TRACKING_LOCALTRACKING.out.trk)

            ch_trk = TRACKING_LOCALTRACKING.out.trk

        }
    }

    if ( params.connectomics ) {

        if ( params.input_deriv ) {
            FETCH_DERIVATIVES ( params.input_deriv )
        }

        if ( params.tracking ) {

            ch_transforms = ANATTODWI.out.warp
                .join(ANATTODWI.out.affine)
            ch_peaks = RECONST_FODF.out.peaks
            ch_fodf = RECONST_FODF.out.fodf
            ch_dwi_bval_bvec = ch_processed_dwi
                .join(ch_processed_bval)
                .join(ch_processed_bvec)
            ch_anat = ANATTODWI.out.t1_warped
            ch_metrics = RECONST_DTIMETRICS.out.fa
                .join(RECONST_DTIMETRICS.out.md)
                .join(RECONST_DTIMETRICS.out.ad)
                .join(RECONST_DTIMETRICS.out.rd)
                .join(RECONST_DTIMETRICS.out.mode)
                .join(RECONST_FODF.out.afd_total)
                .join(RECONST_FODF.out.nufo)
                .map{ meta, fa, md, ad, rd, mode, afd_total, nufo ->
                    tuple(meta, [ fa, md, ad, rd, mode, afd_total, nufo ])}

        } else {

            FETCH_DERIVATIVES ( params.input_deriv )

            ch_trk = FETCH_DERIVATIVES.out.trk
            ch_transforms = FETCH_DERIVATIVES.out.transforms
            ch_peaks = FETCH_DERIVATIVES.out.peaks
            ch_fodf = FETCH_DERIVATIVES.out.fodf
            ch_dwi_bval_bvec = FETCH_DERIVATIVES.out.dwi_bval_bvec
            ch_anat = FETCH_DERIVATIVES.out.anat
            ch_metrics = FETCH_DERIVATIVES.out.metrics

        }

        if ( params.segmentation ) {

            ch_labels = SEGMENTATION.out.labels

        } else {

            ch_labels = FETCH_DERIVATIVES.out.labels

        }
        //
        // MODULE : Run AntsApplyTransforms.
        //
        ch_labels = ch_labels.branch {
            reg: it.size() > 2
                return [it[0], it[2]]
            notreg: it.size() < 3
                return [it[0], it[1]]
        }

        ch_antsapply = ch_labels.notreg
            .join(ch_anat)
            .join(ch_transforms)

        TRANSFORM_LABELS ( ch_antsapply )
        ch_versions = ch_versions.mix(TRANSFORM_LABELS.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(TRANSFORM_LABELS.out.zip.collect{it[1]})
        ch_nifti_files_to_transform = ch_nifti_files_to_transform
            .mix(TRANSFORM_LABELS.out.warped_image)

        //
        // MODULE: Run DECOMPOSE.
        //
        ch_decompose = ch_trk
            .join(ch_labels.reg, remainder: true)
            .map { id, trk, reg_label ->
                reg_label ? [id, trk, reg_label] : [id, trk, null]
            }
            .join(TRANSFORM_LABELS.out.warped_image.map { id, warped -> [id, warped] }, remainder: true)
            .map { id, trk, reg_label, warped_label ->
                def label = reg_label ?: warped_label
                [id, trk, label]
            }

        CONNECTIVITY_DECOMPOSE ( ch_decompose )
        ch_versions = ch_versions.mix(CONNECTIVITY_DECOMPOSE.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(TRACTOGRAM_DECOMPOSE.out.zip.collect{it[1]})

        //
        // MODULE: Run FILTERING_COMMIT
        //
        ch_commit = CONNECTIVITY_DECOMPOSE.out.hdf5
            .join(ch_dwi_bval_bvec)
            .join(ch_peaks)

        FILTERING_COMMIT ( ch_commit )
        ch_versions = ch_versions.mix(FILTERING_COMMIT.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(FILTERING_COMMIT.out.zip.collect{it[1]})
        ch_trk_files_to_transform = ch_trk_files_to_transform
            .mix(FILTERING_COMMIT.out.hdf5)

        //
        // MODULE: Run AFDFIXEL
        //
        ch_afdfixel = FILTERING_COMMIT.out.hdf5
            .join(ch_fodf)

        CONNECTIVITY_AFDFIXEL ( ch_afdfixel )
        ch_versions = ch_versions.mix(CONNECTIVITY_AFDFIXEL.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(CONNECTIVITY_AFDFIXEL.out.zip.collect{it[1]})
        ch_trk_files_to_transform = ch_trk_files_to_transform
            .mix(CONNECTIVITY_AFDFIXEL.out.hdf5)

        //
        // MODULE: Run CONNECTIVITY_METRICS
        //
        ch_metrics_conn = CONNECTIVITY_AFDFIXEL.out.hdf5
            .join(ch_labels.reg, remainder: true)
            .map { id, trk, reg_label ->
                reg_label ? [id, trk, reg_label] : [id, trk, null]
            }
            .join(TRANSFORM_LABELS.out.warped_image.map { id, warped -> [id, warped] }, remainder: true)
            .map { id, trk, reg_label, warped_label ->
                def label = reg_label ?: warped_label
                [id, trk, label]
            }
            .join(CONNECTIVITY_DECOMPOSE.out.labels_list)
            .join(ch_metrics)

        CONNECTIVITY_METRICS ( ch_metrics_conn )
        ch_versions = ch_versions.mix(CONNECTIVITY_METRICS.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(CONNECTIVITY_METRICS.out.zip.collect{it[1]})

        //
        // MODULE: Run CONNECTIVITY_VISUALIZE
        //
        ch_visualize = CONNECTIVITY_METRICS.out.metrics
            .join(CONNECTIVITY_DECOMPOSE.out.labels_list)
            .map{ meta, metrics, labels -> [meta, metrics, [], labels] }

        CONNECTIVITY_VISUALIZE ( ch_visualize )
        ch_versions = ch_versions.mix(CONNECTIVITY_VISUALIZE.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(CONNECTIVITY_VISUALIZE.out.zip.collect{it[1]})

        ch_labels_qc = ch_labels.reg
            .join(TRANSFORM_LABELS.out.warped_image.map { id, warped -> [id, warped] }, remainder: true)
            .map { id, reg_label, warped_label ->
                def label = reg_label ?: warped_label
                [id, label]
            }
    }

    //
    // SUBWORKFLOW: RUN OUTPUT_TEMPLATE_SPACE
    //
    if ( params.template ) {
        ch_nifti_files_to_transform = ch_nifti_files_to_transform
            .groupTuple()
            .map { meta, nii_list ->
                def images = nii_list.flatten().findAll { it != null }
                return tuple(meta, images)
            }

        ch_trk_files_to_transform = ch_trk_files_to_transform
            .groupTuple()
            .map{ meta, trk_list ->
                def trk = trk_list.flatten().findAll { it != null }
                return tuple(meta, trk)
            }

        OUTPUT_TEMPLATE_SPACE(
            ANATTODWI.out.t1_warped,
            ch_nifti_files_to_transform,
            ch_trk_files_to_transform
        )
        ch_versions = ch_versions.mix(OUTPUT_TEMPLATE_SPACE.out.versions)
    }

    //
    // SUBWORKFLOW: RUN QC
    //
    if ( params.tracking && !params.infant ) {
        ch_tissueseg = FASTSEG.out.wm_mask
            .join(FASTSEG.out.gm_mask)
            .join(FASTSEG.out.csf_mask)
    } else if ( params.infant && params.tracking ) {
        ch_tissueseg = MASKS.out.wm_mask
            .join(MASKS.out.gm_mask)
            .join(MASKS.out.csf_mask)
    } else {
        ch_tissueseg = Channel.empty()
    }

    if ( params.tracking ) {
        ch_anat_qc = ANATTODWI.out.t1_warped
    } else if ( params.infant && params.segmentation ) {
        ch_anat_qc = SEGMENTATION.out.t2
    } else if (!params.infant && params.segmentation ) {
        ch_anat_qc = SEGMENTATION.out.t1
    } else {
        ch_anat_qc = ch_anat
    }

    QC (
        ch_anat_qc,
        ch_tissueseg,
        params.connectomics ? ch_labels_qc : params.segmentation ? SEGMENTATION.out.labels : Channel.empty(),
        params.connectomics ? FILTERING_COMMIT.out.trk : params.tracking ? ch_trk : Channel.empty(),
        params.tracking ? ch_inputs.dwi_bval_bvec : params.connectomics ? ch_dwi_bval_bvec : Channel.empty(),
        params.tracking ? RECONST_DTIMETRICS.out.fa : Channel.empty(),
        params.tracking ? RECONST_DTIMETRICS.out.md : Channel.empty(),
        params.tracking ? RECONST_FODF.out.nufo : Channel.empty(),
        params.tracking ? RECONST_DTIMETRICS.out.rgb : Channel.empty()
    )

    qc_files = ch_multiqc_files_sub
        .mix(QC.out.tissueseg_png)
        .mix(QC.out.tracking_png)
        .mix(QC.out.shell_png)
        .mix(QC.out.metrics_png)
        .mix(QC.out.labels_png)
        .groupTuple()
        .map { meta, png_list ->
            def images = png_list.flatten().findAll { it != null }
            return tuple(meta, images)
        }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'nf-pediatric_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = Channel.empty()  // To store versions, methods description, etc.
                                        // Otherwise, stored in either subject or global level channel.

    ch_multiqc_config_subject = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_config_global = Channel.fromPath(
        "$projectDir/assets/multiqc_config_global.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.fromPath("$projectDir/assets/nf-pediatric-logo.png", checkIfExists: true)

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC_SUBJECT (
        qc_files,
        ch_multiqc_files.collect(),
        ch_multiqc_config_subject.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    ch_multiqc_files_global = ch_multiqc_files.mix(QC.out.dice_stats.map{ it[1] }.flatten())
    ch_multiqc_files_global = ch_multiqc_files_global.mix(QC.out.sc_values.map{ it[1] }.flatten())
    if ( params.segmentation ) {
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.volume_lh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.volume_rh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.area_lh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.area_rh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.thickness_lh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.thickness_rh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(SEGMENTATION.out.subcortical)
    }

    MULTIQC_GLOBAL (
        Channel.of([meta:[id:"global"], qc_images:[]]),
        ch_multiqc_files_global.collect(),
        ch_multiqc_config_global.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC_SUBJECT.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
