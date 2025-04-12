include { UTILS_TEMPLATEFLOW as GET     } from '../../../modules/local/utils/templateflow/main'
include { IMAGE_APPLYMASK as MASK       } from '../../../modules/nf-neuro/image/applymask/main'

workflow TEMPLATES {

    main:

    ch_versions = Channel.empty()

    //
    // Fetching the required templates if not arleady available
    //
    def templateExists = file("${params.templateflow_home}/tpl-UNCInfant").exists()

    if ( !templateExists ) {
        ch_template = Channel.from(
            [
                ["UNCInfant", [], []]
            ]
        )
        GET(ch_template)
        ch_versions = ch_versions.mix(GET.out.versions)

        // Wait for GET process to complete
        ch_get_complete = GET.out.folder.toList().map { _it -> true }
    } else {
        ch_get_complete = Channel.of(true)
    }

    //
    // Loading back up in a structured format (stratified by cohorts)
    //
    ch_UNCInfant_cohort1 = ch_get_complete.map { _it ->
            def meta = [id: "UNCInfant", cohort: 1]
            def files = [
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-1/*1_T1w.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-1/*label-brain_mask.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-1/*WM_probseg.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-1/*GM_probseg.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-1/*CSF_probseg.nii.gz")
            ]
            def flattenedFiles = files.flatten().findAll { it }
            [meta] + flattenedFiles
        }
    ch_UNCInfant_cohort2 = ch_get_complete.map { _it ->
            def meta = [id: "UNCInfant", cohort: 2]
            def files = [
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-2/*2_T1w.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-2/*label-brain_mask.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-2/*WM_probseg.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-2/*GM_probseg.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-2/*CSF_probseg.nii.gz")
            ]
            def flattenedFiles = files.flatten().findAll { it }
            [meta] + flattenedFiles
        }
    ch_UNCInfant_cohort3 = ch_get_complete.map { _it ->
            def meta = [id: "UNCInfant", cohort: 3]
            def files = [
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-3/*3_T1w.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-3/*label-brain_mask.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-3/*WM_probseg.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-3/*GM_probseg.nii.gz"),
                file("${params.templateflow_home}/tpl-UNCInfant/cohort-3/*CSF_probseg.nii.gz")
            ]
            def flattenedFiles = files.flatten().findAll { it }
            [meta] + flattenedFiles
        }

    //
    // Apply brain mask on the template.
    //
    ch_mask = ch_UNCInfant_cohort1.mix(ch_UNCInfant_cohort2).mix(ch_UNCInfant_cohort3)
        .map{ it[0..2] }

    MASK ( ch_mask )
    ch_versions = ch_versions.mix(MASK.out.versions)

    // ** Setting outputs ** //
    ch_UNCInfant_cohort1 = MASK.out.image
        .join(ch_UNCInfant_cohort1)
        .map{ meta, bet, _t1w, _mask, wm, gm, csf ->
            [meta, bet, wm, gm, csf]}
    ch_UNCInfant_cohort2 = MASK.out.image
        .join(ch_UNCInfant_cohort2)
        .map{ meta, bet, _t1w, _mask, wm, gm, csf ->
            [meta, bet, wm, gm, csf]}
    ch_UNCInfant_cohort3 = MASK.out.image
        .join(ch_UNCInfant_cohort3)
        .map{ meta, bet, _t1w, _mask, wm, gm, csf ->
            [meta, bet, wm, gm, csf]}

    emit:
    UNCInfant1              = ch_UNCInfant_cohort1 // channel: [ meta, bet, wm, gm, csf ]
    UNCInfant2              = ch_UNCInfant_cohort2 // channel: [ meta, bet, wm, gm, csf ]
    UNCInfant3              = ch_UNCInfant_cohort3 // channel: [ meta, bet, wm, gm, csf ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

