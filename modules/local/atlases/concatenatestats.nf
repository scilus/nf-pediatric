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
    """
    #!/bin/python

    import pandas as pd
    import glob

    for stat in ['volume', 'area', 'thickness', 'subcortical']:
        if stat == 'subcortical':
            files = glob.glob("*subcortical*")
            df = pd.concat([pd.read_csv(f, sep='\\t') for f in files], ignore_index=True)
            df.rename(columns={df.columns[0]: "Sample"}, inplace=True)
            df.to_csv(f"{stat}_volumes.tsv", sep='\\t', index=False)
        else:
            for hemi in ['lh', 'rh']:
                files = glob.glob(f"*{stat}_{hemi}*")
                df = pd.concat([pd.read_csv(f, sep='\\t') for f in files], ignore_index=True)
                df.rename(columns={df.columns[0]: "Sample"}, inplace=True)
                df.to_csv(f"cortical_{stat}_{hemi}.tsv", sep='\\t', index=False)
    """
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        neurostatx: 0.1.0
    END_VERSIONS
    """

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
        neurostatx: 0.1.0
    END_VERSIONS
    """
}
