process CONNECTIVITY_VISUALIZE {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(npy), path(labels_list)

    output:
    tuple val(meta), path("*.png"), emit: png
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    String npy_list = npy.join(", ").replace(',', '')

    """
    for matrix in $npy_list; do
        scil_viz_connectivity.py \$matrix \${matrix/.npy/_matrix.png} \
            --name_axis --display_legend --histogram \${matrix/.npy/_histogram.png} \
            --nb_bins 50 --exclude_zeros --axis_text_size 5 5 \
            --labels_list $labels_list
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__ad.png
    touch ${prefix}__rd.png

    scil_viz_connectivity.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
