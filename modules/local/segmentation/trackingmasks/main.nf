process SEGMENTATION_TRACKINGMASKS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "https://scil.usherbrooke.ca/containers/scilus_latest.sif":
        "scilus/scilus:latest"}"

    input:
    tuple val(meta), path(wm), path(gm), path(csf), path(fa)

    output:
    tuple val(meta), path("*wm_mask.nii.gz")        , emit: wm
    tuple val(meta), path("*gm_mask.nii.gz")        , emit: gm
    tuple val(meta), path("*csf_mask.nii.gz")       , emit: csf
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Thresholding the maps.
    mrthreshold $wm ${prefix}__wm_mask.nii.gz -abs 0.5 -nthreads 1 -force
    mrthreshold $gm ${prefix}__gm_mask.nii.gz -abs 0.5 -nthreads 1 -force
    mrthreshold $csf ${prefix}__csf_mask.nii.gz -abs 0.5 -nthreads 1 -force

    # Thresholding the FA map.
    bet $fa ${prefix}__brain.nii.gz -m -f 0.16
    #scil_volume_math.py erosion ${prefix}__brain_mask.nii.gz 6 ${prefix}__brain_mask.nii.gz -f
    mrcalc $fa ${prefix}__brain_mask.nii.gz -mul ${prefix}__fa_eroded.nii.gz -nthreads 1 -force
    mrthreshold $fa ${prefix}__fa_mask.nii.gz -abs 0.10 -nthreads 1 -force
    scil_volume_math.py union ${prefix}__wm_mask.nii.gz ${prefix}__fa_mask.nii.gz ${prefix}__wm_mask.nii.gz \
        --data_type uint8 -f


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        mrtrix: \$(mrcalc -version 2>&1 | sed -n 's/== mrcalc \\([0-9.]\\+\\).*/\\1/p')
        fsl: \$(flirt -version 2>&1 | sed -n 's/FLIRT version \\([0-9.]\\+\\)/\\1/p')
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
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        mrtrix: \$(mrcalc -version 2>&1 | sed -n 's/== mrcalc \\([0-9.]\\+\\).*/\\1/p')
        fsl: \$(flirt -version 2>&1 | sed -n 's/FLIRT version \\([0-9.]\\+\\)/\\1/p')
    END_VERSIONS

    function handle_code () {
    local code=\$?
    ignore=( 1 )
    exit \$([[ " \${ignore[@]} " =~ " \$code " ]] && echo 0 || echo \$code)
    }
    trap 'handle_code' ERR

    bet -h
    mrthreshold -h
    mrcalc -h
    scil_volume_math.py -h
    """
}
