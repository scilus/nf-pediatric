process SEGMENTATION_FASTSURFER {
    tag "$meta.id"
    label 'process_high'

    container "${ 'gagnonanthony/nf-pediatric-fastsurfer:v2.3.3' }"
    containerOptions {
        (workflow.containerEngine == 'docker') ? '--entrypoint ""': ''
    }

    input:
        tuple val(meta), path(anat), path(fs_license)

    output:
        tuple val(meta), path("*_fastsurfer")       , emit: fastsurferdirectory
        tuple val(meta), path("*__final_t1.nii.gz") , emit: final_t1
        path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def acq3T = task.ext.acq3T ? "--3T" : ""
    def FASTSURFER_HOME = "/fastsurfer"
    //def SUBJECTS_DIR = "${prefix}_fastsurfer"

    // ** Adding a registration to .gca atlas to generate the talairach.m3z file (subcortical atlas segmentation ** //
    // ** wont work without it). A little time consuming but necessary. For FreeSurfer 7.3.2, RB_all_2020-01-02.gca ** //
    // ** is the default atlas. Update when bumping FreeSurfer version. ** //
    """
    export FS_LICENSE=\$(realpath $fs_license)

    $FASTSURFER_HOME/run_fastsurfer.sh  --allow_root \
                                        --sd \$(pwd) \
                                        --fs_license \$(realpath $fs_license) \
                                        --t1 \$(realpath ${anat}) \
                                        --sid ${prefix}__fastsurfer \
                                        --parallel \
                                        --threads $task.cpus \
                                        --py python3 \
                                        ${acq3T}

    mri_ca_register -align-after -nobigventricles -mask ${prefix}__fastsurfer/mri/brainmask.mgz \
        -T ${prefix}__fastsurfer/mri/transforms/talairach.lta -threads $task.cpus \
        ${prefix}__fastsurfer/mri/norm.mgz \${FREESURFER_HOME}/average/RB_all_2020-01-02.gca \
        ${prefix}__fastsurfer/mri/transforms/talairach.m3z

    mri_convert ${prefix}__fastsurfer/mri/antsdn.brain.mgz ${prefix}__final_t1.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastsurfer: \$($FASTSURFER_HOME/run_fastsurfer.sh --version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def FASTSURFER_HOME = "/fastsurfer"

    """
    $FASTSURFER_HOME/run_fastsurfer.sh --version

    mkdir ${prefix}__fastsurfer
    touch ${prefix}__final_t1.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastsurfer: \$($FASTSURFER_HOME/run_fastsurfer.sh --version)
    END_VERSIONS
    """
}
