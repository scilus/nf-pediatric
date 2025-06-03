process SEGMENTATION_TRACKINGMASKS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "https://scil.usherbrooke.ca/containers/scilus_latest.sif":
        "scilus/scilus:latest"}"

    input:
    tuple val(meta), path(wm), path(gm), path(csf)

    output:
    tuple val(meta), path("*wm_mask.nii.gz")        , emit: wm
    tuple val(meta), path("*gm_mask.nii.gz")        , emit: gm
    tuple val(meta), path("*csf_mask.nii.gz")       , emit: csf
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // ** Modular threshold setting depending on the participant's age ** //
    def threshold = meta.age < 0.5 || meta.age > 18 ? 0.15 : 0.30

    """
    # Thresholding the maps.
    mrthreshold $wm ${prefix}__wm_mask.nii.gz -abs 0.4 -nthreads 1 -force
    mrthreshold $gm ${prefix}__gm_mask.nii.gz -abs 0.4 -nthreads 1 -force
    mrthreshold $csf ${prefix}__csf_mask.nii.gz -abs 0.4 -nthreads 1 -force

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mrtrix: \$(mrcalc -version 2>&1 | sed -n 's/== mrcalc \\([0-9.]\\+\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__wm_mask.nii.gz
    touch ${prefix}__gm_mask.nii.gz
    touch ${prefix}__csf_mask.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mrtrix: \$(mrcalc -version 2>&1 | sed -n 's/== mrcalc \\([0-9.]\\+\\).*/\\1/p')
    END_VERSIONS

    function handle_code () {
    local code=\$?
    ignore=( 1 )
    exit \$([[ " \${ignore[@]} " =~ " \$code " ]] && echo 0 || echo \$code)
    }
    trap 'handle_code' ERR

    mrthreshold -h
    """
}
