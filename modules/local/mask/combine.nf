process MASK_COMBINE {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(mask), path(fa)

    output:
    tuple val(meta), path("*seeding_mask.nii.gz")       , emit: wm_mask
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def local_fa_seeding_mask_thr = task.ext.local_fa_seeding_mask_thr ?: 0.2

    """
    bet $fa fa_bet -m -f 0.16
    scil_volume_math.py erosion fa_bet_mask.nii.gz 3 fa_bet_mask.nii.gz -f
    mrcalc fa_bet.nii.gz fa_bet_mask.nii.gz -mult fa_eroded.nii.gz
    mrthreshold fa_eroded.nii.gz ${prefix}__fa_mask.nii.gz -abs $local_fa_seeding_mask_thr -nthreads 1 -force
    scil_volume_math.py union ${prefix}__fa_mask.nii.gz $mask \
        ${prefix}__seeding_mask.nii.gz --data_type uint8 -f

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        mrtrix: \$(mrthreshold --version | sed -n '1p')
        fsl: \$(flirt -version 2>&1 | sed -n 's/FLIRT version \\([0-9.]\\+\\)/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}__seeding_mask.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        mrtrix: \$(mrthreshold --version | sed -n '1p')
        fsl: \$(flirt -version 2>&1 | sed -n 's/FLIRT version \\([0-9.]\\+\\)/\\1/p')
    END_VERSIONS
    """
}
