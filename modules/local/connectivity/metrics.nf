process CONNECTIVITY_METRICS {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(h5), path(labels), path(labels_list), path(metrics)

    output:
    tuple val(meta), path("*.npy"), emit: metrics
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    if ( metrics ) {
        metrics_list = metrics.join(", ").replace(',', '')

        """
        metrics_args=""

        for metric in $metrics_list; do
            base_name=\$(basename \${metric})
            metrics_args="\${metrics_args} --metrics \${metric} \$(basename \$base_name .nii.gz).npy"
        done

        scil_connectivity_compute_matrices.py $h5 $labels \
            --processes $task.cpus \
            --volume "${prefix}__vol.npy" \
            --streamline_count "${prefix}__sc.npy" \
            --length "${prefix}__len.npy" \
            \$metrics_args \
            --density_weighting \
            --no_self_connection \
            --include_dps ./ \
            --force_labels_list $labels_list

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    } else {
        """
        scil_connectivity_compute_matrices.py $h5 $labels \
            --processes $task.cpus \
            --volume "${prefix}__vol.npy" \
            --streamline_count "${prefix}__sc.npy" \
            --length "${prefix}__len.npy" \
            --density_weighting \
            --no_self_connection \
            --include_dps ./ \
            --force_labels_list $labels_list

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    if ( metrics ) {
        metrics_list = metrics.join(", ").replace(',', '')

        """
        for metric in $metrics_list; do
            base_name=\$(basename "\${metric}" .nii.gz)
            touch "\${base_name}.npy"
        done

        scil_connectivity_compute_matrices.py -h

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    } else {
        """
        touch ${prefix}__vol.npy
        touch ${prefix}__sc.npy
        touch ${prefix}__len.npy

        scil_connectivity_compute_matrices.py -h

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    }
}
