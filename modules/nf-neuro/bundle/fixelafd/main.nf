process BUNDLE_FIXELAFD {
    tag "$meta.id"
    label 'process_single'

    container "scilus/scilpy:2.2.1_cpu"

    input:
        tuple val(meta), path(bundles), path(fodf)

    output:
        tuple val(meta), path("*_afd_fixel_metric.nii.gz")  , emit: fixel_afd
        path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    for bundle in $bundles;
        do\
        pos=\$((\$(echo \$bundle | grep -b -o __ | cut -d: -f1)+2))
        bname=\${bundle:\$pos}
        bname=\$(basename \$bname \${ext})
        scil_bundle_mean_fixel_afd \$bundle $fodf ${prefix}__\${bname}_afd_fixel_metric.nii.gz
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(uv pip -q -n list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    scil_bundle_mean_fixel_afd -h

    for bundle in ${bundles};
        do
        ext=\${bundle#*.}
        pos=\$((\$(echo \$bundle | grep -b -o __ | cut -d: -f1)+2))
        bname=\${bundle:\$pos}
        bname=\$(basename \$bname \${ext})
        touch ${prefix}__\${bname}_afd_fixel_metric.nii.gz
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(uv pip -q -n list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
