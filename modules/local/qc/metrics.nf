process QC_METRICS {
    tag "$meta.id"
    label 'process_single'

    container 'scilus/scilus:latest'

    input:
    tuple val(meta), path(fa), path(md), path(nufo), path(rgb)

    output:
    tuple val(meta), path("*metrics_mqc.png")   , emit: png
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Fetch middle axial slice.
    size=\$(mrinfo $fa -size)
    mid_slice=\$(echo \$size | awk '{print int((\$3 + 1) / 2)}')

    scil_viz_volume_screenshot.py $fa ${prefix}_fa.png \
        --slices \$mid_slice --axis axial \
        --display_lr

    scil_viz_volume_screenshot.py $md ${prefix}_md.png \
        --slices \$mid_slice --axis axial \
        --display_lr

    scil_viz_volume_screenshot.py $nufo ${prefix}_nufo.png \
        --slices \$mid_slice --axis axial \
        --display_lr

    scil_viz_volume_screenshot.py $rgb ${prefix}_rgb.png \
        --slices \$mid_slice --axis axial \
        --display_lr

    # Merge images using ImageMagick.
    convert ${prefix}_fa*.png ${prefix}_md*.png ${prefix}_rgb*.png ${prefix}_nufo*.png +append ${prefix}_metrics_mqc.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}_metrics_mqc.png

    scil_viz_volume_screenshot.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
