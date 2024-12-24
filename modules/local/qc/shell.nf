process QC_SHELL {
    tag "$meta.id"
    label 'process_single'

    container 'gagnonanthony/nf-pediatric-qc:1.0.0'

    input:
    tuple val(meta), path(bval), path(bvec)

    output:
    tuple val(meta), path("*_mqc.png")      , emit: shell
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    scil_viz_gradients_screenshot.py --in_gradient_scheme $bvec $bval \
        --out_basename ${prefix}_gradients_mqc --res 600

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}_gradients_mqc.png

    scil_viz_gradients_screenshot.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
