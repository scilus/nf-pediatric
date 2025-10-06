process SEGMENTATION_MASKS {
    tag "$meta.id"
    label 'process_single'

    container 'scilus/scilus:2.0.2'

    input:
    tuple val(meta), path(aseg), path(fa)

    output:
    tuple val(meta), path("*_wm_mask.nii.gz")       , emit: wm_mask
    tuple val(meta), path("*_gm_mask.nii.gz")       , emit: gm_mask
    tuple val(meta), path("*_csf_mask.nii.gz")      , emit: csf_mask
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def local_fa_seeding_mask_thr = task.ext.local_fa_seeding_mask_thr ?: 0.2

    """
    scil_labels_combine.py \
        --volume_ids $aseg 3 8 9 11 12 13 17 18 42 47 48 50 51 52 53 54 \
        --out_labels_ids 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 -f \
        ${prefix}__gm_mask.nii.gz
    scil_labels_combine.py \
        --volume_ids $aseg 2 16 41 85 253 \
        --out_labels_ids 1 1 1 1 1 -f \
        ${prefix}__wm_mask.nii.gz
    scil_labels_combine.py \
        --volume_ids $aseg 4 43 \
        --out_labels_ids 1 1 -f \
        ${prefix}__csf_mask.nii.gz

    # Threshold the FA map.
    bet $fa ${prefix}__brain_mask.nii.gz -m -f 0.16
    scil_volume_math.py erosion ${prefix}__brain_mask_mask.nii.gz 3 ${prefix}__brain_mask.nii.gz -f
    mrcalc $fa ${prefix}__brain_mask.nii.gz -mul ${prefix}__fa_eroded.nii.gz -nthreads 1 -force
    mrthreshold $fa ${prefix}__fa_mask.nii.gz -abs $local_fa_seeding_mask_thr -nthreads 1 -force
    scil_volume_math.py union ${prefix}__wm_mask.nii.gz ${prefix}__fa_mask.nii.gz ${prefix}__wm_mask.nii.gz \
        --data_type uint8 -f

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}__wm_mask.nii.gz
    touch ${prefix}__gm_mask.nii.gz
    touch ${prefix}__csf_mask.nii.gz

    scil_labels_combine.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
