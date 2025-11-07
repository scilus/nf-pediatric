process MERGE_TSV {
    tag "global"
    label 'process_single'

    container "${ 'gagnonanthony/neurostatx:0.1.0' }"

    input:
    tuple val(meta), path(tsv)

    output:
    path "bundles_mean_stats.tsv"           , emit: bundle_mean_stats
    path "bundles_point_stats.tsv"          , emit: bundle_point_stats
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'mergetsv.py'

    stub:
    """
    touch bundles_mean_stats.tsv
    touch bundles_point_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 -c 'import platform; print(platform.python_version())')
        pandas: \$(python3 -c 'import pandas; print(pandas.__version__)')
    END_VERSIONS
    """
}
