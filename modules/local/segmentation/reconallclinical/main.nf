process SEGMENTATION_RECONALLCLINICAL {
    tag "$meta.id"
    label 'process_ml'

    conda "${moduleDir}/environment.yml"
    container "${ 'gagnonanthony/nf-pediatric-freesurfer:8.0.0' }"

    input:
    tuple val(meta), path(anat), path(fs_license)

    output:
    tuple val(meta), path("*__freesurfer"), emit: folder
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def SUBJECTS_DIR="./${prefix}__freesurfer"

    """
    mkdir -p ${SUBJECTS_DIR}
    export FS_LICENSE=\$(realpath $fs_license)

    recon-all-clinical.sh \
        -i $anat \
        -subjid $prefix \
        -sdir $SUBJECTS_DIR \
        -threads $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        freesurfer: 8.0.0
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def SUBJECTS_DIR="./${prefix}__freesurfer"

    """
    mkdir -p ${SUBJECTS_DIR}/${prefix}/mri/transforms \
        ${SUBJECTS_DIR}/${prefix}/label/ \
        ${SUBJECTS_DIR}/${prefix}/surf/ \
        ${SUBJECTS_DIR}/${prefix}/stats/ \
        ${SUBJECTS_DIR}/${prefix}/scripts/ \
        ${SUBJECTS_DIR}/${prefix}/tmp/ \
        ${SUBJECTS_DIR}/${prefix}/touch/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        freesurfer: 8.0.0
    END_VERSIONS

    function handle_code () {
    local code=\$?
    ignore=( 1 )
    exit \$([[ " \${ignore[@]} " =~ " \$code " ]] && echo 0 || echo \$code)
    }
    trap 'handle_code' ERR

    recon-all-clinical.sh --help
    """
}
