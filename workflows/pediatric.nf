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
include { methodsDescriptionText            } from '../subworkflows/local/utils_nfcore_pediatric_pipeline'

// ** T1 reconstruction ** //
include { FREESURFERFLOW                    } from '../subworkflows/local/freesurferflow/freesurferflow'

// ** T1 Preprocessing ** //
include { PREPROC_T1                        } from '../subworkflows/nf-neuro/preproc_t1/main'
include { IMAGE_RESAMPLE as RESAMPLE_T2     } from '../modules/nf-neuro/image/resample/main'
include { IMAGE_RESAMPLE as RESAMPLE_WMMASK } from '../modules/nf-neuro/image/resample/main'
include { BETCROP_CROPVOLUME as CROPT2      } from '../modules/nf-neuro/betcrop/cropvolume/main'
include { BETCROP_CROPVOLUME as CROPWMMASK  } from '../modules/nf-neuro/betcrop/cropvolume/main'

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
include { REGISTRATION                      } from '../subworkflows/nf-neuro/registration/main'
include { REGISTRATION_ANTSAPPLYTRANSFORMS  } from '../modules/nf-neuro/registration/antsapplytransforms/main'

// ** Anatomical Segmentation ** //
include { ANATOMICAL_SEGMENTATION           } from '../subworkflows/nf-neuro/anatomical_segmentation/main'
include { MASK_COMBINE                      } from '../modules/local/mask/combine.nf'

// ** Tracking ** //
include { TRACKING_PFTTRACKING              } from '../modules/nf-neuro/tracking/pfttracking/main'
include { TRACKING_LOCALTRACKING            } from '../modules/nf-neuro/tracking/localtracking/main'

// ** Connectomics ** //
include { REGISTRATION_ANTSAPPLYTRANSFORMS as TRANSFORM_LABELS } from '../modules/nf-neuro/registration/antsapplytransforms/main'
include { FILTERING_COMMIT                  } from '../modules/local/filtering/commit.nf'
include { TRACTOGRAM_DECOMPOSE              } from '../modules/local/tractogram/decompose.nf'
include { CONNECTIVITY_AFDFIXEL             } from '../modules/local/connectivity/afdfixel.nf'
include { CONNECTIVITY_METRICS              } from '../modules/local/connectivity/metrics.nf'
include { CONNECTIVITY_VISUALIZE            } from '../modules/local/connectivity/visualize.nf'

// ** QC ** //
include { QC } from '../subworkflows/local/QC/qc.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PEDIATRIC {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Decomposing the samplesheet into individual channels
    //
    ch_inputs = ch_samplesheet
        .multiMap{ meta, t1, t2, dwi, bval, bvec, rev_b0, labels, wmparc, trk, peaks, fodf, mat, warp, metrics ->
            t1: [meta, t1]
            t2: [meta, t2]
            dwi_bval_bvec: [meta, dwi, bval, bvec]
            rev_b0: [meta, rev_b0]
            labels: [meta, labels]
            wmparc: [meta, wmparc]
            trk: [meta, trk]
            peaks: [meta, peaks]
            fodf: [meta, fodf]
            mat: [meta, mat]
            warp: [meta, warp]
            metrics: [meta, metrics]
        }

    //
    // SUBWORKFLOW: Run FastSurfer or FreeSurfer T1 reconstruction with BrainnetomeChild atlas
    //
    if ( params.freesurfer ) {

        // ** Fetch license file ** //
        ch_fs_license = params.fs_license
            ? Channel.fromPath(params.fs_license, checkIfExists: true, followLinks: true)
            : Channel.empty().ifEmpty { error "No license file path provided. Please specify the path using --fs_license parameter." }

        // ** Fetch utils folder ** //
        ch_utils_folder = Channel.fromPath(params.utils_folder, checkIfExists: true)

        FREESURFERFLOW (
            ch_inputs.t1,
            ch_fs_license,
            ch_utils_folder
        )

        ch_versions = ch_versions.mix(FREESURFERFLOW.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(FASTSURFER.out.zip.collect{it[1]})

    }

    //
    // SUBWORKFLOW: Run PREPROC_T1
    //
    if ( !params.infant && params.tracking && !params.freesurfer ) {

        ch_template = Channel.fromPath(params.t1_bet_template, checkIfExists: true)
        ch_probability_map = Channel.fromPath(params.t1_bet_template_probability_map, checkIfExists: true)
            .map{ it + [[], []] }
        if ( params.t1_synthstrip_weights ) {
            ch_t1_weights = Channel.fromPath(params.t1_synthstrip_weights, checkIfExists: false)
        } else {
            ch_t1_weights = Channel.empty()
        }

        ch_meta = ch_inputs.t1.map{ it[0] }
        PREPROC_T1 (
            ch_inputs.t1,
            ch_meta.combine(ch_template),
            ch_meta.combine(ch_probability_map),
            Channel.empty(),
            Channel.empty(),
            Channel.empty(),
            ch_meta.combine(ch_t1_weights)
        )
        ch_versions = ch_versions.mix(PREPROC_T1.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(PREPROC_T1.out.zip.collect{it[1]})
    }

    //
    // SUBWORKFLOW: Run PREPROC_DWI
    //
    if ( params.tracking ) {

        /* Load topup config if provided */
        if ( params.dwi_susceptibility_config_file ) {
            if ( file(params.dwi_susceptibility_config_file).exists() ) {
                ch_topup_config = Channel.fromPath(params.dwi_susceptibility_config_file, checkIfExists: true)
            }
            else {
                ch_topup_config = Channel.fromPath( params.dwi_susceptibility_config_file )
            }
        }

        if ( params.dwi_synthstrip_weights ) {
            ch_dwi_weights = Channel.fromPath(params.dwi_synthstrip_weights, checkIfExists: false)
        } else {
            ch_dwi_weights = Channel.value([])
        }

        /* Run DWI preprocessing if the data isn't already preprocessed */
        /* else, just resample and crop the data                        */
        if ( !params.skip_dwi_preprocessing ) {

            PREPROC_DWI(
                ch_inputs.dwi_bval_bvec,
                Channel.empty(),
                Channel.empty(),
                ch_inputs.rev_b0,
                ch_topup_config,
                ch_dwi_weights
            )
            ch_versions = ch_versions.mix(PREPROC_DWI.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(PREPROC_DWI.out.zip.collect{it[1]})

            // ** Setting outputs ** //
            ch_processed_dwi = PREPROC_DWI.out.dwi_resample
            ch_processed_bval = PREPROC_DWI.out.bval
            ch_processed_bvec = PREPROC_DWI.out.bvec
            ch_processed_b0 = PREPROC_DWI.out.b0
            ch_processed_b0_mask = PREPROC_DWI.out.b0_mask

        } else {

            ch_resample_dwi = ch_inputs.dwi_bval_bvec
                .map{ it[0..1] + [[]] }

            // ** Resample the already preprocessed DWI ** //
            RESAMPLE_DWI ( ch_resample_dwi )
            ch_versions = ch_versions.mix(RESAMPLE_DWI.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(RESAMPLE_DWI.out.zip.collect{it[1]})

            ch_crop_dwi = RESAMPLE_DWI.out.image
                .map{ it + [[]] }

            // ** Crop the already resampled DWI ** //
            CROPDWI ( ch_crop_dwi )
            ch_versions = ch_versions.mix(CROPDWI.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(CROPDWI.out.zip.collect{it[1]})

            ch_extract_b0 = CROPDWI.out.image
                .join(ch_inputs.dwi_bval_bvec)
                .map{ it[0..1] + it [3..4] }

            // ** Extract the b0 from the already cropped DWI ** //
            EXTRACTB0 ( ch_extract_b0 )
            ch_versions = ch_versions.mix(EXTRACTB0.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(EXTRACTB0.out.zip.collect{it[1]})

            // ** Setting outputs ** //
            ch_processed_dwi = CROPDWI.out.image
            ch_processed_bval = ch_inputs.dwi_bval_bvec.map{ [it[0], it [2]] }
            ch_processed_bvec = ch_inputs.dwi_bval_bvec.map{ [it[0], it [3]] }
            ch_processed_b0 = EXTRACTB0.out.b0
            ch_processed_b0_mask = EXTRACTB0.out.b0_mask
        }

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

        //
        // MODULE: Run REGISTRATION
        //
        if ( params.infant ) {

            // ** Apply resampling to input t2 and wmparc. ** //
            ch_resample_t2 = ch_inputs.t2
                .map{ it + [[]] }

            RESAMPLE_T2 ( ch_resample_t2 )
            ch_versions = ch_versions.mix(RESAMPLE_T2.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(RESAMPLE_T2.out.zip.collect{it[1]})

            ch_resample_wmmask = ch_inputs.wmparc
                .map{ it + [[]] }

            RESAMPLE_WMMASK ( ch_resample_wmmask )
            ch_versions = ch_versions.mix(RESAMPLE_WMMASK.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(RESAMPLE_WMMASK.out.zip.collect{it[1]})

            // ** Crop T2 and wm mask. ** //
            ch_crop_t2 = RESAMPLE_T2.out.image
                .map{ it + [[]] }

            CROPT2 ( ch_crop_t2 )
            ch_versions = ch_versions.mix(CROPT2.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(CROPT2.out.zip.collect{it[1]})

            ch_crop_wmmask = RESAMPLE_WMMASK.out.image
                .join(CROPT2.out.bounding_box)

            CROPWMMASK ( ch_crop_wmmask )
            ch_versions = ch_versions.mix(CROPWMMASK.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(CROPWMMASK.out.zip.collect{it[1]})

            REGISTRATION(
                CROPT2.out.image,
                ch_processed_b0,
                RECONST_DTIMETRICS.out.md,
                Channel.empty(),
                Channel.empty(),
                Channel.empty()
            )
            ch_versions = ch_versions.mix(REGISTRATION.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(REGISTRATION.out.zip.collect{it[1]})

            // ** Apply transforms to WM mask. ** //
            ch_reg_wm_mask = CROPWMMASK.out.image
                .join(REGISTRATION.out.image_warped)
                .join(REGISTRATION.out.transfo_image)

            REGISTRATION_ANTSAPPLYTRANSFORMS ( ch_reg_wm_mask )
            ch_versions = ch_versions.mix(REGISTRATION_ANTSAPPLYTRANSFORMS.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(REGISTRATION_ANTSAPPLYTRANSFORMS.out.zip.collect{it[1]})

        } else {

            REGISTRATION(
                params.freesurfer ? FREESURFERFLOW.out.t1 : PREPROC_T1.out.t1_final,
                ch_processed_b0,
                RECONST_DTIMETRICS.out.fa,
                Channel.empty(),
                Channel.empty(),
                Channel.empty()
            )
            ch_versions = ch_versions.mix(REGISTRATION.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(REGISTRATION.out.zip.collect{it[1]})
        }

        //
        // SUBWORKFLOW: Run ANATOMICAL_SEGMENTATION
        //
        if ( params.infant ) {

            ch_seg = REGISTRATION_ANTSAPPLYTRANSFORMS.out.warped_image
                .join(RECONST_DTIMETRICS.out.fa)

            MASK_COMBINE( ch_seg )
            ch_versions = ch_versions.mix(MASK_COMBINE.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(MASK_COMBINE.out.zip.collect{it[1]})

            ch_wm_mask = MASK_COMBINE.out.wm_mask

        } else {

            ANATOMICAL_SEGMENTATION(
                REGISTRATION.out.image_warped,
                Channel.empty(),
                Channel.empty(),
                Channel.empty()
            )
            ch_versions = ch_versions.mix(ANATOMICAL_SEGMENTATION.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(ANATOMICAL_SEGMENTATION.out.zip.collect{it[1]})

            ch_wm_mask = ANATOMICAL_SEGMENTATION.out.wm_mask
        }

        //
        // MODULE: Run PFT_TRACKING
        //
        if ( params.run_pft_tracking ) {

            ch_pft_tracking = ANATOMICAL_SEGMENTATION.out.wm_map
                .join(ANATOMICAL_SEGMENTATION.out.gm_map)
                .join(ANATOMICAL_SEGMENTATION.out.csf_map)
                .join(RECONST_FODF.out.fodf)
                .join(RECONST_DTIMETRICS.out.fa)

            TRACKING_PFTTRACKING ( ch_pft_tracking )
            ch_versions = ch_versions.mix(TRACKING_PFTTRACKING.out.versions.first())
            // ch_multiqc_files = ch_multiqc_files.mix(TRACKING_PFTTRACKING.out.zip.collect{it[1]})

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

            ch_trk = TRACKING_LOCALTRACKING.out.trk

        }
    }

    if ( params.connectomics ) {

        if ( params.freesurfer ) {

            ch_labels = FREESURFERFLOW.out.labels

        } else {

            ch_labels = ch_inputs.labels

        }

        if ( params.tracking ) {

            ch_transforms = REGISTRATION.out.transfo_image
            ch_peaks = RECONST_FODF.out.peaks
            ch_fodf = RECONST_FODF.out.fodf
            ch_dwi_bval_bvec = ch_processed_dwi
                .join(ch_processed_bval)
                .join(ch_processed_bvec)
            ch_anat = REGISTRATION.out.image_warped
            ch_metrics = RECONST_DTIMETRICS.out.fa
                .join(RECONST_DTIMETRICS.out.md)
                .join(RECONST_DTIMETRICS.out.ad)
                .join(RECONST_DTIMETRICS.out.rd)
                .join(RECONST_DTIMETRICS.out.mode)
                .join(RECONST_FODF.out.afd_total)
                .join(RECONST_FODF.out.nufo)
                .map{ meta, fa, md, ad, rd, mode, afd_total, nufo ->
                    tuple(meta, [ fa, md, ad, rd, mode, afd_total, nufo ])}

            ch_provided_metrics = ch_inputs.metrics
                .map { meta, metrics ->
                    def metrics_files = file("$metrics/*.nii.gz").findAll { it.name.endsWith('.nii.gz') && it.name != '*.nii.gz' }
                    return [meta, metrics_files]
                }
                .filter { it[1].size() > 0 }

            ch_metrics = ch_metrics.join(ch_provided_metrics, remainder: true)
                .map { meta, defmet, provmet ->
                    def met = provmet ? tuple(meta, defmet + provmet) : tuple(meta, defmet)
                    return met
                }

        } else {

            ch_trk = ch_inputs.trk
            ch_transforms = ch_inputs.warp
                .join(ch_inputs.mat)
            ch_peaks = ch_inputs.peaks
            ch_fodf = ch_inputs.fodf
            ch_dwi_bval_bvec = ch_inputs.dwi_bval_bvec

            if ( params.infant ) {
                ch_anat = ch_inputs.t2
            } else {
                ch_anat = ch_inputs.t1
            }

            ch_metrics = ch_inputs.metrics
                .map { meta, metrics ->
                    def metrics_files = file("$metrics/*.nii.gz").findAll { it.name.endsWith('.nii.gz') && it.name != '*.nii.gz' }
                    return [meta, metrics_files]
                }
                .filter { it[1] }

        }
        //
        // MODULE : Run AntsApplyTransforms.
        //
        ch_antsapply = ch_labels
            .join(ch_anat)
            .join(ch_transforms)

        TRANSFORM_LABELS ( ch_antsapply )
        ch_versions = ch_versions.mix(TRANSFORM_LABELS.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(TRANSFORM_LABELS.out.zip.collect{it[1]})

        //
        // MODULE: Run DECOMPOSE.
        //
        ch_decompose = ch_trk
            .join(TRANSFORM_LABELS.out.warped_image)

        TRACTOGRAM_DECOMPOSE ( ch_decompose )
        ch_versions = ch_versions.mix(TRACTOGRAM_DECOMPOSE.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(TRACTOGRAM_DECOMPOSE.out.zip.collect{it[1]})

        //
        // MODULE: Run FILTERING_COMMIT
        //
        ch_commit = TRACTOGRAM_DECOMPOSE.out.hdf5
            .join(ch_dwi_bval_bvec)
            .join(ch_peaks)

        FILTERING_COMMIT ( ch_commit )
        ch_versions = ch_versions.mix(FILTERING_COMMIT.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(FILTERING_COMMIT.out.zip.collect{it[1]})

        //
        // MODULE: Run AFDFIXEL
        //
        ch_afdfixel = FILTERING_COMMIT.out.hdf5
            .join(ch_fodf)

        CONNECTIVITY_AFDFIXEL ( ch_afdfixel )
        ch_versions = ch_versions.mix(CONNECTIVITY_AFDFIXEL.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(CONNECTIVITY_AFDFIXEL.out.zip.collect{it[1]})

        //
        // MODULE: Run CONNECTIVITY_METRICS
        //
        ch_metrics_conn = CONNECTIVITY_AFDFIXEL.out.hdf5
            .join(TRANSFORM_LABELS.out.warped_image)
            .join(TRACTOGRAM_DECOMPOSE.out.labels_list)
            .join(ch_metrics, remainder: true)
            .map{ it[0..3] + [it[4] ?: []] }

        CONNECTIVITY_METRICS ( ch_metrics_conn )
        ch_versions = ch_versions.mix(CONNECTIVITY_METRICS.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(CONNECTIVITY_METRICS.out.zip.collect{it[1]})

        //
        // MODULE: Run CONNECTIVITY_VISUALIZE
        //
        ch_visualize = CONNECTIVITY_METRICS.out.metrics
            .join(TRACTOGRAM_DECOMPOSE.out.labels_list)

        CONNECTIVITY_VISUALIZE ( ch_visualize )
        ch_versions = ch_versions.mix(CONNECTIVITY_VISUALIZE.out.versions.first())
        // ch_multiqc_files = ch_multiqc_files.mix(CONNECTIVITY_VISUALIZE.out.zip.collect{it[1]})

    }

    //
    // SUBWORKFLOW: RUN QC
    //
    if ( params.tracking && !params.infant ) {
        ch_tissueseg = ANATOMICAL_SEGMENTATION.out.wm_mask
            .join(ANATOMICAL_SEGMENTATION.out.gm_mask)
            .join(ANATOMICAL_SEGMENTATION.out.csf_mask)
    } else if ( params.infant && params.tracking ) {
        ch_tissueseg = MASK_COMBINE.out.wm_mask
    } else {
        ch_tissueseg = Channel.empty()
    }

    QC (
        params.tracking ? REGISTRATION.out.image_warped : params.freesurfer ? FREESURFERFLOW.out.t1 : params.infant ? ch_inputs.t2 : ch_inputs.t1,
        ch_tissueseg,
        params.connectomics ? TRANSFORM_LABELS.out.warped_image : params.freesurfer ? FREESURFERFLOW.out.labels : Channel.empty(),
        params.connectomics ? FILTERING_COMMIT.out.trk : params.tracking ? ch_trk : Channel.empty(),
        params.tracking || params.connectomics ? ch_inputs.dwi_bval_bvec : Channel.empty(),
        params.tracking ? RECONST_DTIMETRICS.out.fa : Channel.empty(),
        params.tracking ? RECONST_DTIMETRICS.out.md : Channel.empty(),
        params.tracking ? RECONST_FODF.out.nufo : Channel.empty(),
        params.tracking ? RECONST_DTIMETRICS.out.rgb : Channel.empty()
    )

    qc_files = QC.out.tissueseg_png
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
            name:  ''  + 'pipeline_software_' +  'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
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
    if ( params.freesurfer ) {
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.volume_lh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.volume_rh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.area_lh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.area_rh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.thickness_lh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.thickness_rh)
        ch_multiqc_files_global = ch_multiqc_files_global.mix(FREESURFERFLOW.out.subcortical)
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
