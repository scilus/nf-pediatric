//
// Subworkflow with functionality specific to the nf-neuro/nf-pediatric pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { UTILS_BIDSLAYOUT          } from '../../../modules/local/utils/bidslayout'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input_bids        //  string: Path to input samplesheet
    bids_script       //  string: Path to BIDS layout script

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Some sanity checks for required inputs.
    //
    if (!input_bids && ( params.segmentation || params.tracking ) ) {
        error "ERROR: Missing input BIDS folder. Please provide a BIDS folder using --input."
    }

    //
    // Create channel from input file provided through params.input
    //
    if ( input_bids ) {
        ch_bids_script = Channel.fromPath(bids_script)
        ch_input_bids = Channel.fromPath(input_bids)

        UTILS_BIDSLAYOUT( ch_input_bids, ch_bids_script )
        ch_versions = ch_versions.mix(UTILS_BIDSLAYOUT.out.versions)

        ch_inputs = UTILS_BIDSLAYOUT.out.layout
            .flatMap{ layout ->
                def json = new groovy.json.JsonSlurper().parseText(layout.getText())
                json.collect { item ->
                    def sid = "sub-" + item.subject

                    def session = item.session ? "ses-" + item.session : ""
                    def run = item.run ? "run-" + item.run : ""
                    def age = item.age ?: ""

                    item.each { _key, value ->
                        if (value == 'todo') {
                            error "ERROR ~ $sid contains missing files, please check the BIDS layout for this subject."
                        }
                    }

                    return [
                        [id: sid, session: session, run: run, age: age.toFloat()],
                        item.t1 ? file(item.t1) : [],
                        item.t2 ? file(item.t2) : [],
                        item.dwi ? file(item.dwi) : [],
                        item.bval ? file(item.bval) : [],
                        item.bvec ? file(item.bvec) : [],
                        item.rev_dwi ? file(item.rev_dwi) : [],
                        item.rev_bval ? file(item.rev_bval) : [],
                        item.rev_bvec ? file(item.rev_bvec) : [],
                        item.rev_topup ? file(item.rev_topup) : []
                    ]
                }
            }
    } else {
        ch_inputs = Channel.empty()
    }

    emit:
    input_bids      = ch_inputs
    versions        = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Generate corresponding template for age groups.
//
def getTemplateAgeGroup(age) {
    def ageGroups = [
        "0-6 months": [0, 0.5],
        "6-18 months": [0.5, 1.5],
        "18-30 months": [1.5, 2.5],
        "30-44 months": [2.5, 3.66666666666667],
        "44-60 months": [3.6666666666666667, 5],
        "5-8.5 years": [5, 8.5],
        "8.5-11 years": [8.5, 11],
        "11-14 years": [11, 14],
        "14-18 years": [14, 18]
    ]

    def templates = [
        "0-6 months": ["UNCInfant", 1],
        "6-18 months": ["UNCInfant", 2],
        "18-30 months": ["UNCInfant", 3],
        "30-44 months": ["MNIInfant", 10],
        "44-60 months": ["MNIInfant", 11],
        "5-8.5 years": ["MNIPediatricAsym", 2],
        "8.5-11 years": ["MNIPediatricAsym", 3],
        "11-14 years": ["MNIPediatricAsym", 5],
        "14-18 years": ["MNIPediatricAsym", 6]
    ]

    ageGroups.each { entry ->
        if (age >= entry.value[0] && age < entry.value[1]) {
            return entry.key
        }
    }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    def citation_text = [
            "Tools used in the workflow included:",
            "scilpy (https://github.com/scilus/scilpy),",
            "Mrtrix (Tournier et al., 2019)",
            "FSL (Jenkinson et al., 2011)",
            "ANTs (Tustison et al., 2021)",
            params.use_fastsurfer ? "FastSurfer (Henschel et al., 2020)" : "",
            params.segmentation ? "FreeSurfer (Fischl, B. 2012)" : "",
            "MultiQC (Ewels et al., 2016)",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    def reference_text = [
            "<li>scilpy, URL: https://github.com/scilus/scilpy</li>",
            "<li>Tournier, J.-D., Smith, R., Raffelt, D., Tabbara, R., Dhollander, T., Pietsch, M., Christiaens, D., Jeurissen, B., Yeh, C.-H., & Connelly, A. (2019). MRtrix3: A fast, flexible and open software framework for medical image processing and visualisation. NeuroImage, 202, 116137. https://doi.org/10.1016/j.neuroimage.2019.116137</li>",
            "<li>Jenkinson, M., Beckmann, C. F., Behrens, T. E. J., Woolrich, M. W., & Smith, S. M. (2012). FSL. NeuroImage, 62(2), 782–790. https://doi.org/10.1016/j.neuroimage.2011.09.015</li>",
            "<li>Tustison, N. J., Cook, P. A., Holbrook, A. J., Johnson, H. J., Muschelli, J., Devenyi, G. A., Duda, J. T., Das, S. R., Cullen, N. C., Gillen, D. L., Yassa, M. A., Stone, J. R., Gee, J. C., & Avants, B. B. (2021). The ANTsX ecosystem for quantitative biological and medical imaging. Scientific Reports, 11(1), 9068. https://doi.org/10.1038/s41598-021-87564-6</li>",
            params.use_fastsurfer ? "<li>Henschel, L., Conjeti, S., Estrada, S., Diers, K., Fischl, B., & Reuter, M. (2020). FastSurfer—A fast and accurate deep learning based neuroimaging pipeline. NeuroImage, 219, 117012. https://doi.org/10.1016/j.neuroimage.2020.117012</li>" : "",
            params.segmentation ? "<li>Fischl, B. (2012). FreeSurfer. NeuroImage, 62(2), 774–781. https://doi.org/10.1016/j.neuroimage.2012.01.021</li>" : "",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>"
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}

