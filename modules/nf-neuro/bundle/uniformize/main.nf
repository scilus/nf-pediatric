process BUNDLE_UNIFORMIZE {
    tag "$meta.id"
    label 'process_single'

    container 'scilus/scilus:2.0.2'

    input:
    tuple val(meta), path(bundles), path(centroids)

    output:
    tuple val(meta), path("*_uniformized.trk"), emit: bundles
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def method = task.ext.method ? "--${task.ext.method}"  : "--auto"
    def swap = task.ext.swap ? "--swap" : ""

    """
    bundles=(${bundles.join(" ")})

    if [[ -f "$centroids" ]]; then
        centroids=(${centroids.join(" ")})
    fi

    for index in \${!bundles[@]};
        do \
        ext=\${bundles[index]#*.}
        pos=\$((\$(echo \${bundles[index]} | grep -b -o __ | cut -d: -f1)+2))
        bname=\${bundles[index]:\$pos}
        bname=\$(basename \${bname} .\${ext})
        if [[ -f "$centroids" ]]; then
            option="--centroid \${centroids[index]}"
        else
            option="$method"
        fi
        scil_bundle_uniformize_endpoints.py \${bundles[index]} ${prefix}__\${bname}_uniformized.trk\
            \${option}\
            $swap -f
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bundles=(${bundles.join(" ")})

    scil_bundle_uniformize_endpoints.py -h

    for index in \${!bundles[@]};
        do \
        ext=\${bundles[index]#*.}
        pos=\$((\$(echo \${bundles[index]} | grep -b -o __ | cut -d: -f1)+2))
        bname=\${bundles[index]:\$pos}
        bname=\$(basename \${bname} .\${ext})
        touch ${prefix}__\${bname}_uniformized.trk
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
