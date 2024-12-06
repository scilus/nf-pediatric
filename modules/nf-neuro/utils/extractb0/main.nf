process UTILS_EXTRACTB0 {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(dwi), path(bval), path(bvec)

    output:
    tuple val(meta), path("*_b0.nii.gz")        , emit: b0
    tuple val(meta), path("*_b0_mask.nii.gz")   , emit: b0_mask
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extraction_strategy = task.ext.b0_extraction_strategy ? "--$task.ext.b0_extraction_strategy" : "--mean"
    def b0_threshold = task.ext.b0_threshold ? "--b0_threshold $task.ext.b0_threshold" : ""
    def output_series = task.ext.output_series ? "" : "--single-image"
    """
    export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1

    scil_dwi_extract_b0.py $dwi $bval $bvec ${prefix}_b0.nii.gz \
        $output_series $extraction_strategy $b0_threshold --skip_b0_check

    mrthreshold ${prefix}_b0.nii.gz ${prefix}_b0_mask.nii.gz -abs 0.0001 \
        -nthreads $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        mrtrix: \$(mrthreshold -version 2>&1 | sed -n 's/== mrthreshold \\([0-9.]\\+\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    scil_dwi_extract_b0.py -h
    mrthreshold -h

    touch ${prefix}_b0.nii.gz
    touch ${prefix}_b0_mask.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        mrtrix: \$(mrthreshold -version 2>&1 | sed -n 's/== mrthreshold \\([0-9.]\\+\\).*/\\1/p')
    END_VERSIONS
    """
}
