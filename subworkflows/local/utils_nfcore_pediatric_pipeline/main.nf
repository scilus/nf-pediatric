//
// Subworkflow with functionality specific to the nf/pediatric pipeline
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
    input             //  string: Path to input samplesheet

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
    // Create channel from input file provided through params.input
    //

    Channel
        .fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
        .map {
            meta, t1, t2, dwi, bval, bvec, rev_b0, labels, wmparc, trk, peaks, fodf, mat, warp, metrics ->

                // ** Check if at least one anatomical image is provided, ** //
                // ** regardless of the profile ** //
                if (!t1 && !t2 ) {
                    error("Please provide at least one anatomical image (T1w or T2w) for sample: ${meta.id}")
                }

                // ** Validate mandatory images for profile infant with only tracking. ** //
                if ( params.infant && params.tracking && !params.connectomics ) {
                    if (!t2) {
                        error("Please provide a T2w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!rev_b0) {
                        error("Please provide a reverse phase encoded B0 image for sample: ${meta.id}")
                    }
                    if (!wmparc) {
                        error("Please provide a wmparc image for sample: ${meta.id}")
                    }
                }

                // ** Validate mandatory files for profile infant with connectomics. ** //
                if ( params.infant && params.connectomics && !params.tracking ) {
                    if (!t2) {
                        error("Please provide a T2w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!labels) {
                        error("Please provide a labels image for sample: ${meta.id}")
                    }
                    if (!trk) {
                        error("Please provide a trk file for sample: ${meta.id}")
                    }
                    if (!peaks) {
                        error("Please provide a peaks image for sample: ${meta.id}")
                    }
                    if (!fodf) {
                        error("Please provide a fodf image for sample: ${meta.id}")
                    }
                    if (!mat) {
                        error("Please provide a mat file for sample: ${meta.id}")
                    }
                    if (!warp) {
                        error("Please provide a warp image for sample: ${meta.id}")
                    }
                    if (!metrics) {
                        log.warn("You did not provide metric file for sample: ${meta.id}")
                    }
                }

                // ** Validate files for profile infant with tracking and connectomics. ** //
                if ( params.infant && params.tracking && params.connectomics ) {
                    if (!t2) {
                        error("Please provide a T2w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!rev_b0) {
                        error("Please provide a reverse phase encoded B0 image for sample: ${meta.id}")
                    }
                    if (!wmparc) {
                        error("Please provide a wmparc image for sample: ${meta.id}")
                    }
                    if (!labels) {
                        error("Please provide a labels image for sample: ${meta.id}")
                    }
                }

                // ** Validate files for profile children with only tracking. ** //
                if ( params.tracking && !params.connectomics && !params.infant ) {
                    if (!t1) {
                        error("Please provide a T1w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!rev_b0) {
                        error("Please provide a reverse phase encoded B0 image for sample: ${meta.id}")
                    }
                }

                // ** Validate files for profile children with connectomics. ** //
                if ( params.connectomics && !params.tracking && !params.infant ) {
                    if (!t1) {
                        error("Please provide a T1w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!labels) {
                        error("Please provide a labels image for sample: ${meta.id}")
                    }
                    if (!trk) {
                        error("Please provide a trk file for sample: ${meta.id}")
                    }
                    if (!peaks) {
                        error("Please provide a peaks image for sample: ${meta.id}")
                    }
                    if (!fodf) {
                        error("Please provide a fodf image for sample: ${meta.id}")
                    }
                    if (!mat) {
                        error("Please provide a mat file for sample: ${meta.id}")
                    }
                    if (!warp) {
                        error("Please provide a warp image for sample: ${meta.id}")
                    }
                    if (!metrics) {
                        log.warn("You did not provide metric file for sample: ${meta.id}")
                    }
                }

                // ** Validate files for profile children with tracking and connectomics. ** //
                if ( params.tracking && params.connectomics && !params.infant && !params.freesurfer ) {
                    if (!t1) {
                        error("Please provide a T1w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!rev_b0) {
                        error("Please provide a reverse phase encoded B0 image for sample: ${meta.id}")
                    }
                    if (!labels) {
                        error("Please provide a labels image for sample: ${meta.id}")
                    }
                }

                // ** Validate files for profile freesurfer with connectomics ** //
                if ( params.connectomics && !params.tracking && params.freesurfer ) {
                    if (!t1) {
                        error("Please provide a T1w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!trk) {
                        error("Please provide a trk file for sample: ${meta.id}")
                    }
                    if (!peaks) {
                        error("Please provide a peaks image for sample: ${meta.id}")
                    }
                    if (!fodf) {
                        error("Please provide a fodf image for sample: ${meta.id}")
                    }
                    if (!mat) {
                        error("Please provide a mat file for sample: ${meta.id}")
                    }
                    if (!warp) {
                        error("Please provide a warp image for sample: ${meta.id}")
                    }
                    if (!metrics) {
                        log.warn("You did not provide metric file for sample: ${meta.id}")
                    }
                }

                // ** Validate files for profile freesurfer with tracking and connectomics ** //
                if ( params.tracking && params.connectomics && params.freesurfer ) {
                    if (!t1) {
                        error("Please provide a T1w image for sample: ${meta.id}")
                    }
                    if (!dwi) {
                        error("Please provide a DWI image for sample: ${meta.id}")
                    }
                    if (!bval) {
                        error("Please provide a bval file for sample: ${meta.id}")
                    }
                    if (!bvec) {
                        error("Please provide a bvec file for sample: ${meta.id}")
                    }
                    if (!rev_b0) {
                        error("Please provide a reverse phase encoded B0 image for sample: ${meta.id}")
                    }
                }

                return [ meta, t1, t2, dwi, bval, bvec, rev_b0, labels, wmparc, trk, peaks, fodf, mat, warp, metrics ]
        }
        .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
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
                multiqc_report.toList()
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
// Generate methods description for MultiQC
//
def toolCitationText() {
    // TODO nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "FastQC (Andrews 2010),",
            "MultiQC (Ewels et al. 2016)",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
            "<li>Andrews S, (2010) FastQC, URL: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).</li>",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>"
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familar NXF ${workflow} variable syntax in the MultiQC YML file
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

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}

