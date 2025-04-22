process ATLASES_CONCATENATESTATS {
    tag "global"
    label 'process_single'

    container "${ 'gagnonanthony/neurostatx:0.1.0' }"

    input:
    tuple val(meta), path(tsv)

    output:
    path("*_volumes.tsv")     , emit: subcortical
    path("*_volume_lh.tsv")      , emit: volume_lh
    path("*_volume_rh.tsv")      , emit: volume_rh
    path("*_area_lh.tsv")        , emit: area_lh
    path("*_area_rh.tsv")        , emit: area_rh
    path("*_thickness_lh.tsv")   , emit: thickness_lh
    path("*_thickness_rh.tsv")   , emit: thickness_rh
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'concatenatestats.py'

    stub:
    """
    touch subcortical_${meta.agegroup}_volumes.tsv
    touch cortical_${meta.agegroup}_volume_lh.tsv
    touch cortical_${meta.agegroup}_volume_rh.tsv
    touch cortical_${meta.agegroup}_area_lh.tsv
    touch cortical_${meta.agegroup}_area_rh.tsv
    touch cortical_${meta.agegroup}_thickness_lh.tsv
    touch cortical_${meta.agegroup}_thickness_rh.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 -c 'import platform; print(platform.python_version())')
        pandas: \$(python3 -c 'import pandas; print(pandas.__version__)')
    END_VERSIONS
    """
}
