process ATLASES_CONCATENATESTATS {
    tag "global"
    label 'process_single'

    container "${ 'gagnonanthony/neurostatx:0.1.0' }"

    input:
    path tsv

    output:
    path("subcortical_volumes.tsv")     , emit: subcortical
    path("cortical_volume_lh.tsv")      , emit: volume_lh
    path("cortical_volume_rh.tsv")      , emit: volume_rh
    path("cortical_area_lh.tsv")        , emit: area_lh
    path("cortical_area_rh.tsv")        , emit: area_rh
    path("cortical_thickness_lh.tsv")   , emit: thickness_lh
    path("cortical_thickness_rh.tsv")   , emit: thickness_rh
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'concatenatestats.py'

    stub:
    """
    touch subcortical_volumes.tsv
    touch cortical_volume_lh.tsv
    touch cortical_volume_rh.tsv
    touch cortical_area_lh.tsv
    touch cortical_area_rh.tsv
    touch cortical_thickness_lh.tsv
    touch cortical_thickness_rh.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 -c 'import platform; print(platform.python_version())')
        pandas: \$(python3 -c 'import pandas; print(pandas.__version__)')
    END_VERSIONS
    """
}
