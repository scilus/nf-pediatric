process CONNECTIVITY_AFDFIXEL {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilpy:1.6.0' }"

    input:
    tuple val(meta), path(h5), path(fodf)

    output:
    tuple val(meta), path("*afd_fixel.h5")  , emit: hdf5
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def sh_basis = task.ext.sh_basis ? "--sh_basis " + task.ext.sh_basis : ""
    def length_weighting = task.ext.length_weighting ? "--length_weighting " + task.ext.length_weighting : ""

    """
    scil_compute_mean_fixel_afd_from_hdf5.py $h5 $fodf "${prefix}__afd_fixel.h5" \
        --processes $task.cpus $sh_basis $length_weighting

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__afd_fixel.h5

    scil_compute_mean_fixel_afd_from_hdf5.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
