process SEGMENTATION_RECONALLCLINICAL {
    tag "$meta.id"
    label 'process_ml'

    conda "${moduleDir}/environment.yml"
    container "${ 'gagnonanthony/nf-pediatric-freesurfer:8.0.0' }"

    input:
    tuple val(meta), path(anat), path(fs_license)

    output:
    tuple val(meta), path("*__freesurfer")      , emit: folder
    tuple val(meta), path("*__final_t1.nii.gz") , emit: final_t1
    path "versions.yml"                         , emit: versions

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

    # To date, best approach is: 1) Use synthstrip to get a complete brain mask,
    # 2) use mri_ca_register to align the brain.mgz to the RB atlas. (add the -optimal flag)
    mv $SUBJECTS_DIR/$prefix/mri/brainmask.mgz $SUBJECTS_DIR/$prefix/mri/brainmask.mgz.bak
    mri_synthstrip \
        -i $SUBJECTS_DIR/$prefix/mri/brain.mgz \
        -m $SUBJECTS_DIR/$prefix/mri/brainmask.mgz \
        --no-csf

    # Using the synthSR.mgz here as it is the norm.mgz equivalent in recon-all-clinical.
    mri_ca_register -optimal -align-after -nobigventricles \
        -mask ${prefix}__freesurfer/${prefix}/mri/brainmask.mgz \
        -T ${prefix}__freesurfer/${prefix}/mri/transforms/talairach.xfm.lta \
        -threads $task.cpus \
        ${prefix}__freesurfer/${prefix}/mri/synthSR.mgz \
        \${FREESURFER_HOME}/average/RB_all_2020-01-02.gca \
        ${prefix}__freesurfer/${prefix}/mri/transforms/talairach.m3z

    # Symlink the native.mgz as orig.mgz for compatibility with other tools/modules.
    ln -s \$(realpath $SUBJECTS_DIR/${prefix}/mri/native.mgz) $SUBJECTS_DIR/$prefix/mri/orig.mgz

    # Replacing brain.mgz with synthSR.mgz
    mv $SUBJECTS_DIR/$prefix/mri/brain.mgz $SUBJECTS_DIR/$prefix/mri/brain.mgz.bak
    cp $SUBJECTS_DIR/$prefix/mri/synthSR.mgz $SUBJECTS_DIR/$prefix/mri/brain.mgz

    # Converting synthSR.mgz to NIfTI format as the final T1 image.
    mri_convert $SUBJECTS_DIR/$prefix/mri/brain.mgz ${prefix}__final_t1.nii.gz

    rm $SUBJECTS_DIR/fsaverage

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

    touch ${prefix}__final_t1.nii.gz

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
