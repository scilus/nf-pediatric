process UTILS_BIDSLAYOUT {
    tag "BIDS"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    path(folder)
    path(script)

    output:
    path("layout.json")         , emit: layout
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    """
    python $script $folder layout.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:

    """
    python $script $folder layout.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
