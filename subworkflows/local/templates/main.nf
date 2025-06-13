include { UTILS_TEMPLATEFLOW as GET     } from '../../../modules/local/utils/templateflow/main'

def createCohortChannel(channel, cohort) {
    channel.map { folder ->
        def meta = [id: "UNCBCPInfant", cohort: cohort]
        def files = [
            file("${folder}/${cohort}/*desc-brain_T1w.nii.gz"),
            file("${folder}/${cohort}/*desc-brain_T2w.nii.gz"),
            file("${folder}/${cohort}/*WM_probseg.nii.gz"),
            file("${folder}/${cohort}/*GM_probseg.nii.gz"),
            file("${folder}/${cohort}/*CSF_probseg.nii.gz")
        ]
        def flattenedFiles = files.flatten().findAll { it.exists() }
        [meta] + flattenedFiles
    }
}

workflow TEMPLATES {

    main:

    ch_versions = Channel.empty()

    //
    // Fetching the required templates if not already available
    //
    /*
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
    */

    // ** Until tpl-UNCBCP4DInfant is available on TemplateFlow, we use ** //
    // ** local folders (in assets/)                                    ** //
    ch_template_folder = Channel.fromPath("${projectDir}/assets/templates")

    ch_cohort0 = createCohortChannel(ch_template_folder, "0M")
    ch_cohort3 = createCohortChannel(ch_template_folder, "3M")
    ch_cohort6 = createCohortChannel(ch_template_folder, "6M")
    ch_cohort12 = createCohortChannel(ch_template_folder, "12M")
    ch_cohort24 = createCohortChannel(ch_template_folder, "24M")


    emit:
    UNCBCPInfant0              = ch_cohort0     // channel: [ meta, T1w, T2w, wm, gm, csf ]
    UNCBCPInfant3              = ch_cohort3     // channel: [ meta, T1w, T2w, wm, gm, csf ]
    UNCBCPInfant6              = ch_cohort6     // channel: [ meta, T1w, T2w, wm, gm, csf ]
    UNCBCPInfant12             = ch_cohort12    // channel: [ meta, T1w, T2w, wm, gm, csf ]
    UNCBCPInfant24             = ch_cohort24    // channel: [ meta, T1w, T2w, wm, gm, csf ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

