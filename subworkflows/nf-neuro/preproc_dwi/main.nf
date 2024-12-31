include { DENOISING_MPPCA as DENOISE_DWI } from '../../../modules/nf-neuro/denoising/mppca/main'
include { DENOISING_MPPCA as DENOISE_REVDWI } from '../../../modules/nf-neuro/denoising/mppca/main'
include { IMAGE_POWDERAVERAGE } from '../../../modules/nf-neuro/image/powderaverage/main'
include { IMAGE_APPLYMASK as BET_DWI } from '../../../modules/nf-neuro/image/applymask/main'
include { BETCROP_SYNTHBET } from '../../../modules/nf-neuro/betcrop/synthbet/main'
include { BETCROP_CROPVOLUME as CROPDWI } from '../../../modules/nf-neuro/betcrop/cropvolume/main'
include { BETCROP_CROPVOLUME as CROPMASK } from '../../../modules/nf-neuro/betcrop/cropvolume/main'
include { IMAGE_CONVERT as CONVERT } from '../../../modules/nf-neuro/image/convert'
include { BETCROP_FSLBETCROP } from '../../../modules/nf-neuro/betcrop/fslbetcrop/main'
include { BETCROP_CROPVOLUME as CROPB0 } from '../../../modules/nf-neuro/betcrop/cropvolume/main'
include { PREPROC_N4 as N4_DWI } from '../../../modules/nf-neuro/preproc/n4/main'
include { PREPROC_NORMALIZE as NORMALIZE_DWI } from '../../../modules/nf-neuro/preproc/normalize/main'
include { IMAGE_RESAMPLE as RESAMPLE_DWI } from '../../../modules/nf-neuro/image/resample/main'
include { IMAGE_RESAMPLE as RESAMPLE_MASK } from '../../../modules/nf-neuro/image/resample/main'
include { UTILS_EXTRACTB0 as EXTRACTB0_RESAMPLE } from '../../../modules/nf-neuro/utils/extractb0/main'
include { UTILS_EXTRACTB0 as EXTRACTB0_TOPUP } from '../../../modules/nf-neuro/utils/extractb0/main'
include { TOPUP_EDDY } from '../topup_eddy/main'


workflow PREPROC_DWI {

    take:
        ch_dwi           // channel: [ val(meta), dwi, bval, bvec ]
        ch_rev_dwi       // channel: [ val(meta), rev-dwi, bval, bvec ], optional
        ch_b0            // Channel: [ val(meta), b0 ], optional
        ch_rev_b0        // channel: [ val(meta), rev-b0 ], optional
        ch_config_topup  // channel: [ 'topup.cnf' ], optional
        ch_weights       // channel: [ 'weights' ], optional

    main:

        ch_versions = Channel.empty()

        ch_dwi_bvalbvec = ch_dwi
            .multiMap { meta, dwi, bval, bvec ->
                dwi:    [ meta, dwi ]
                bvs_files: [ meta, bval, bvec ]
            }

        ch_rev_dwi_bvalbvec = ch_rev_dwi
            .multiMap { meta, dwi, bval, bvec ->
                rev_dwi:    [ meta, dwi ]
                rev_bvs_files: [ meta, bval, bvec ]
            }

        // ** Denoise DWI ** //
        ch_denoise_dwi = ch_dwi_bvalbvec.dwi
            .map{ it + [[]] }

        DENOISE_DWI ( ch_denoise_dwi )
        ch_versions = ch_versions.mix(DENOISE_DWI.out.versions.first())

        // ** Denoise REV-DWI ** //
        // Need to append "rev" to the ID, to ensure output filenames
        // are different from the DWI and prevent file collisions
        //  - "cache: meta" is used to save the "real" metadata with valid ID for
        //           join operations, so it can be recovered after execution
        ch_denoise_rev_dwi = ch_rev_dwi_bvalbvec.rev_dwi
            .map{ meta, dwi -> [ [id: "${meta.id}_rev", cache: meta], dwi, [] ] }

        DENOISE_REVDWI ( ch_denoise_rev_dwi )
        ch_versions = ch_versions.mix(DENOISE_REVDWI.out.versions.first())

        // ** Eddy Topup ** //
        ch_topup_eddy_dwi = DENOISE_DWI.out.image
            .join(ch_dwi_bvalbvec.bvs_files)

        // Recover the "real" ID from "meta[cache]" (see above), to join with the bval/bvec
        ch_topup_eddy_rev_dwi = DENOISE_REVDWI.out.image
            .map{ meta, dwi -> [ meta.cache, dwi ] }
            .join(ch_rev_dwi_bvalbvec.rev_bvs_files)

        TOPUP_EDDY ( ch_topup_eddy_dwi, ch_b0, ch_topup_eddy_rev_dwi, ch_rev_b0, ch_config_topup )
        ch_versions = ch_versions.mix(TOPUP_EDDY.out.versions.first())

        // ** Bet-crop DWI ** //
        if ( params.dwi_run_synthstrip ) {

            ch_pwd_avg = TOPUP_EDDY.out.dwi
                .join(TOPUP_EDDY.out.bval)
                .map{ it + [[]] }

            IMAGE_POWDERAVERAGE ( ch_pwd_avg )
            ch_versions = ch_versions.mix(IMAGE_POWDERAVERAGE.out.versions.first())
            ch_pwdavg = IMAGE_POWDERAVERAGE.out.pwd_avg

            ch_synthstrip = IMAGE_POWDERAVERAGE.out.pwd_avg
                .combine(ch_weights)
                .map { it ->
                    def pwd_avg = it[0..1]
                    def weights = it.size() > 2 ? it[2] : []
                    pwd_avg + [weights]
                }

            BETCROP_SYNTHBET ( ch_synthstrip )
            ch_versions = ch_versions.mix(BETCROP_SYNTHBET.out.versions.first())

            ch_apply_mask = TOPUP_EDDY.out.dwi
                .join(BETCROP_SYNTHBET.out.brain_mask)

            BET_DWI ( ch_apply_mask )
            ch_versions = ch_versions.mix(BET_DWI.out.versions.first())

            CROPDWI ( BET_DWI.out.image
                .map{ it + [[]] })
            ch_versions = ch_versions.mix(CROPDWI.out.versions.first())

            ch_cropmask = BETCROP_SYNTHBET.out.brain_mask
                .join(CROPDWI.out.bounding_box)
            CROPMASK ( ch_cropmask )
            ch_versions = ch_versions.mix(CROPMASK.out.versions.first())

            CONVERT ( CROPMASK.out.image )
            ch_versions = ch_versions.mix(CONVERT.out.versions.first())

            ch_dwi = CROPDWI.out.image
            ch_mask = CONVERT.out.image
            ch_bbox = CROPDWI.out.bounding_box

        } else {

            ch_pwdavg = Channel.empty()
            ch_betcrop_dwi = TOPUP_EDDY.out.dwi
                .join(TOPUP_EDDY.out.bval)
                .join(TOPUP_EDDY.out.bvec)

            BETCROP_FSLBETCROP ( ch_betcrop_dwi )
            ch_versions = ch_versions.mix(BETCROP_FSLBETCROP.out.versions.first())

            ch_dwi = BETCROP_FSLBETCROP.out.image
            ch_mask = BETCROP_FSLBETCROP.out.mask
            ch_bbox = BETCROP_FSLBETCROP.out.bbox

        }

        // ** Crop b0 ** //
        ch_crop_b0 = TOPUP_EDDY.out.b0
            .join(ch_bbox)
        CROPB0 ( ch_crop_b0 )
        ch_versions = ch_versions.mix(CROPB0.out.versions.first())

        // ** N4 DWI ** //
        ch_N4 = ch_dwi
            .join(CROPB0.out.image)
            .join(ch_mask)

        N4_DWI ( ch_N4 )
        ch_versions = ch_versions.mix(N4_DWI.out.versions.first())

        // ** Normalize DWI ** //
        ch_normalize = N4_DWI.out.image
            .join(TOPUP_EDDY.out.bval)
            .join(TOPUP_EDDY.out.bvec)
            .join(ch_mask)

        NORMALIZE_DWI ( ch_normalize )
        ch_versions = ch_versions.mix(NORMALIZE_DWI.out.versions.first())

        // ** Resample DWI ** //
        ch_resample_dwi = NORMALIZE_DWI.out.dwi
            .map{ it + [[]] }

        RESAMPLE_DWI ( ch_resample_dwi )
        ch_versions = ch_versions.mix(RESAMPLE_DWI.out.versions.first())

        // ** Extract b0 ** //
        ch_dwi_extract_b0 =   RESAMPLE_DWI.out.image
            .join(TOPUP_EDDY.out.bval)
            .join(TOPUP_EDDY.out.bvec)

        EXTRACTB0_RESAMPLE { ch_dwi_extract_b0 }
        ch_versions = ch_versions.mix(EXTRACTB0_RESAMPLE.out.versions.first())

        // ** Resample mask ** //
        ch_resample_mask = ch_mask.map{ it + [[]] }

        RESAMPLE_MASK ( ch_resample_mask )
        ch_versions = ch_versions.mix(RESAMPLE_MASK.out.versions.first())

    emit:
        dwi_resample        = RESAMPLE_DWI.out.image        // channel: [ val(meta), dwi-resampled ]
        bval                = TOPUP_EDDY.out.bval           // channel: [ val(meta), bval-corrected ]
        bvec                = TOPUP_EDDY.out.bvec           // channel: [ val(meta), bvec-corrected ]
        pwdavg              = ch_pwdavg                     // channel: [ val(meta), [ pwdavg ] ]
        b0                  = EXTRACTB0_RESAMPLE.out.b0     // channel: [ val(meta), b0-resampled ]
        b0_mask             = RESAMPLE_MASK.out.image       // channel: [ val(meta), b0-mask ]
        dwi_bounding_box    = ch_bbox                       // channel: [ val(meta), [ dwi_bounding_box ] ]
        dwi_topup_eddy      = TOPUP_EDDY.out.dwi            // channel: [ val(meta), dwi-after-topup-eddy ]
        dwi_n4              = N4_DWI.out.image              // channel: [ val(meta), dwi-after-n4 ]
        versions            = ch_versions                   // channel: [ versions.yml ]
}
