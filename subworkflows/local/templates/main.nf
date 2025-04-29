include { UTILS_TEMPLATEFLOW as GET     } from '../../../modules/local/utils/templateflow/main'
include { IMAGE_APPLYMASK as MASK       } from '../../../modules/nf-neuro/image/applymask/main'

def createCohortChannel(channel, cohort) {
    channel.map { folder ->
        def meta = [id: "UNCInfant", cohort: cohort]
        def files = [
            file("${folder}/cohort-${cohort}/*desc-brain_T1w.nii.gz"),
            file("${folder}/cohort-${cohort}/*WM_probseg.nii.gz"),
            file("${folder}/cohort-${cohort}/*GM_probseg.nii.gz"),
            file("${folder}/cohort-${cohort}/*CSF_probseg.nii.gz")
        ]
        def flattenedFiles = files.flatten().findAll { it.exists() }
        [meta] + flattenedFiles
    }
}

workflow TEMPLATES {

    main:

    ch_versions = Channel.empty()

    //
    // Fetching the required templates if not arleady available
    //
    def templateExists = file("${params.templateflow_home}/tpl-UNCInfant").exists()

    if (!templateExists) {
        ch_template = Channel.from([["UNCInfant", [], []]])
        GET(ch_template)
        ch_versions = ch_versions.mix(GET.out.versions)
        ch_template_folder = GET.out.folder
    } else {
        ch_template_folder = Channel.fromPath("${params.templateflow_home}/tpl-UNCInfant")
    }

    // Create channels for each cohort
    ch_UNCInfant_cohort1 = createCohortChannel(ch_template_folder, 1)
    ch_UNCInfant_cohort2 = createCohortChannel(ch_template_folder, 2)
    ch_UNCInfant_cohort3 = createCohortChannel(ch_template_folder, 3)

    emit:
    UNCInfant1              = ch_UNCInfant_cohort1 // channel: [ meta, bet, wm, gm, csf ]
    UNCInfant2              = ch_UNCInfant_cohort2 // channel: [ meta, bet, wm, gm, csf ]
    UNCInfant3              = ch_UNCInfant_cohort3 // channel: [ meta, bet, wm, gm, csf ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

