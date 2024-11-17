process ATLASES_BRAINNETOMECHILD {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?:
        'gagnonanthony/nf-pediatric:0.1.0' }"

    input:
    tuple val(meta), path(folder), path(utils), path(fs_license)

    output:
    tuple val(meta), path("*brainnetome_child_v1.nii.gz")               , emit: labels
    tuple val(meta), path("*brainnetome_child_v1_dilated.nii.gz")       , emit: labels_dilate
    tuple val(meta), path("*[brainnetome_child]*.txt")                  , emit: labels_txt
    tuple val(meta), path("*[brainnetome_child]*.json")                 , emit: labels_json
    tuple val(meta), path("*.stats")                                    , emit: stats
    path "versions.yml"                                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    export FS_LICENSE=./license.txt

    ln -s $utils/fsaverage \$(dirname ${folder})/
    bash $utils/freesurfer_utils/generate_atlas_BN_child.sh \$(dirname ${folder}) \
        ${prefix}__recon_all ${task.cpus} Brainnetome_Child/
    cp ${prefix}__recon_all/Brainnetome_Child/* ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        freesurfer: \$(mri_convert -version | grep "freesurfer" | sed -E 's/.* ([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__brainnetome_child_v1.nii.gz
    touch ${prefix}__brainnetome_child_v1_dilated.nii.gz
    touch ${prefix}__brainnetome_child_v1.txt
    touch ${prefix}__brainnetome_child_v1.json
    touch ${prefix}__brainnetome_child_v1.stats

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
        freesurfer: \$(mri_convert -version | grep "freesurfer" | sed -E 's/.* ([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS
    """
}
