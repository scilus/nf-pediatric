process MULTIQC {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.25.2--pyhdfd78af_0' :
        'multiqc/multiqc:v1.25.2' }"

    input:
    tuple val(meta), path(qc_images)
    path  multiqc_files
    path(multiqc_config)
    path(extra_multiqc_config)
    path(multiqc_logo)
    path(replace_names)
    path(sample_names)

    output:
    path "*.html"              , emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional:true, emit: plots
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = "${meta.id}"
    def config = multiqc_config ? "--config $multiqc_config" : ''
    def extra_config = extra_multiqc_config ? "--config $extra_multiqc_config" : ''
    def logo = multiqc_logo ? "--cl-config 'custom_logo: \"${multiqc_logo}\"'" : ''
    def replace = replace_names ? "--replace-names ${replace_names}" : ''
    def samples = sample_names ? "--sample-names ${sample_names}" : ''
    """
    # Process SC txt files if they exist
    if ls *__sc.txt 1> /dev/null 2>&1; then
        echo -e "Sample\tSC_Value" > sc_values.txt
        for sc in *__sc.txt; do
            sample_name=\$(basename \$sc __sc.txt)
            sc_value=\$(cat \$sc)
            echo -e "\${sample_name}\\t\${sc_value}" >> sc_values.txt
        done
    fi

    # Process Dice score txt files if they exist
    if ls *__dice.txt 1> /dev/null 2>&1; then
        echo -e "Sample\tDice_Score" > dice_values.txt
        for dice in *__dice.txt; do
            sample_name=\$(basename \$dice __dice.txt)
            dice_value=\$(cat \$dice)
            echo -e "\${sample_name}\\t\${dice_value}" >> dice_values.txt
        done
    fi

    multiqc . -v \
        --force \
        $args \
        $config \
        --filename ${prefix}.html \
        $extra_config \
        $logo \
        $replace \
        $samples \
        --comment "This report contains QC images for subject ${prefix}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """

    stub:
    def prefix = "${meta.id}"
    """
    mkdir ${prefix}_multiqc_data
    mkdir ${prefix}_multiqc_plots
    touch ${prefix}_multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}