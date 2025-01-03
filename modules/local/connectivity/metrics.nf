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
    def atlas = task.ext.atlas

    if ( metrics ) {
        metrics_list = metrics.join(", ").replace(',', '')

        """
        metrics_args=""

        for metric in $metrics_list; do
            base_name=\$(basename \${metric} .nii.gz)

            # Fetch metric tag.
            stat=\$(echo "\$base_name" | cut -d'_' -f3)

            metrics_args="\${metrics_args} --metrics \${metric} ${prefix}_seg-${atlas}_stat-\${stat}.npy"
        done

        scil_connectivity_compute_matrices.py $h5 $labels \
            --processes $task.cpus \
            --volume "${prefix}_seg-${atlas}_stat-vol.npy" \
            --streamline_count "${prefix}_seg-${atlas}_stat-sc.npy" \
            --length "${prefix}_seg-${atlas}_stat-len.npy" \
            \$metrics_args \
            --density_weighting \
            --no_self_connection \
            --include_dps ./ \
            --force_labels_list $labels_list

        # Rename commit or afd_fixel files if they exist.
        if [ -f afd_fixel.npy ]; then
            mv afd_fixel.npy ${prefix}_seg-${atlas}_stat-afd_fixel.npy
        fi

        if [ -f commit*.npy ]; then
            mv commit*.npy ${prefix}_seg-${atlas}_stat-commit_weights.npy
        fi

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    } else {
        """
        scil_connectivity_compute_matrices.py $h5 $labels \
            --processes $task.cpus \
            --volume "${prefix}_seg-${atlas}_stat-vol.npy" \
            --streamline_count "${prefix}_seg-${atlas}_stat-sc.npy" \
            --length "${prefix}_seg-${atlas}_stat-len.npy" \
            --density_weighting \
            --no_self_connection \
            --include_dps ./ \
            --force_labels_list $labels_list

        # Rename commit or afd_fixel files if they exist.
        if [ -f afd_fixel.npy ]; then
            mv afd_fixel.npy ${prefix}_seg-${atlas}_stat-afd_fixel.npy
        fi

        if [ -f commit*.npy ]; then
            mv commit*.npy ${prefix}_seg-${atlas}_stat-commit_weights.npy
        fi

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def atlas = task.ext.atlas

    if ( metrics ) {
        metrics_list = metrics.join(", ").replace(',', '')

        """
        for metric in $metrics_list; do
            base_name=\$(basename \${metric} .nii.gz)

            # Fetch metric tag.
            stat=\$(echo "\$base_name" | cut -d'_' -f3)

            touch ${prefix}_seg-${atlas}_stat-\${stat}.npy
        done

        scil_connectivity_compute_matrices.py -h

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    } else {
        """
        touch ${prefix}_seg-${atlas}_stat-vol.npy
        touch ${prefix}_seg-${atlas}_stat-sc.npy
        touch ${prefix}_seg-${atlas}_stat-len.npy

        scil_connectivity_compute_matrices.py -h

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        END_VERSIONS
        """
    }
}
