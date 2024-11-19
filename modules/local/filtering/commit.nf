process FILTERING_COMMIT {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilpy:1.6.0' }"

    input:
    tuple val(meta), path(trk), path(dwi), path(bval), path(bvec), path(peaks)

    output:
    tuple val(meta), path("*results_bzs")   , emit: results
    tuple val(meta), path("*commit*")       , emit: trk

    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def para_diff = task.ext.para_diff ? "--para_diff " + task.ext.para_diff : ""
    def iso_diff = task.ext.iso_diff ? "--iso_diff " + task.ext.iso_diff : ""
    def perp_diff = task.ext.perp_diff ? "--perp_diff " + task.ext.perp_diff : ""
    def ball_stick = task.ext.ball_stick ? "--ball_stick" : ""
    def commit2 = task.ext.commit2 ? "--commit2" : ""
    def commit2_lambda = task.ext.commit2_lambda ? "--lambda_commit_2 " + task.ext.commit2_lambda : ""
    def nbr_dir = task.ext.nbr_dir ? "--nbr_dir " + task.ext.nbr_dir : ""
    //def shell_tolerance = task.ext.shell_tolerance ? "--b0_thr " + task.ext.shell_tolerance : ""

    def peaks_arg = peaks ? "--in_peaks $peaks" : ""

    """
    export DIPY_HOME="./"

    scil_run_commit.py $trk $dwi $bval $bvec "${prefix}__results_bzs/" \
        --processes $task.cpus $para_diff $iso_diff $perp_diff $ball_stick \
        $commit2 $commit2_lambda $nbr_dir $peaks_arg

    if [ -f "${prefix}__results_bzs/commit_2/decompose_commit.h5" ]; then
        mv "${prefix}__results_bzs/commit_2/decompose_commit.h5" "./${prefix}__decompose_commit.h5"
    elif [ -f "${prefix}__results_bzs/commit_1/decompose_commit.h5" ]; then
        mv "${prefix}__results_bzs/commit_1/decompose_commit.h5" "./${prefix}__decompose_commit.h5"
    else
        mv "${prefix}__results_bzs/commit_1/essential_tractogram.trk" "./${prefix}__commit.trk"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__commit.trk
    mkdir ${prefix}__results_bzs

    scil_run_commit.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
