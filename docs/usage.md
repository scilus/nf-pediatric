# nf-pediatric: Usage

## Introduction

`nf-pediatric` process MRI pediatric data from 0-18 years old. It includes a variety of profiles that performs different steps of the pipeline and can be activated or deactivated by the user. A specific and unique profile pertains to `infant` data (<2 years old) and sets specific parameters tailored to infant data preprocessing. Here is a list of the available profiles:

- `tracking`: Perform DWI preprocessing, DTI and FODF modelling, anatomical segmentation, and tractography. Final outputs are the DTI/FODF metric maps, whole-brain tractogram, registered anatomical image, etc.
- `freesurfer`: Run FreeSurfer or FastSurfer for T1w surface reconstruction. Then, the [Brainnetome Child Atlas](https://academic.oup.com/cercor/article/33/9/5264/6762896) is mapped to the subject space. **Not available with the `infant` profile.**
- `connectomics`: Perform tractogram segmentation according to an atlas, tractogram filtering, and compute metrics. Final outputs are connectivity matrices.
- `infant`: This profile adapt some processing steps to infant data, but also requires more input files. See below for a list of the required files.

## Samplesheet input for the `tracking` profile.

You will need to create a samplesheet with information about the subjects you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

`samplesheet.csv`:

```csv
subject,t1,t2,dwi,bval,bvec,rev_b0,labels,wmparc,trk,peaks,fodf,mat,warp,metrics
sub-1000,/input/sub-1000/t1.nii.gz,/input/sub-1000/dwi.nii.gz,/input/sub-1000/dwi.bval,/input/sub-1000/dwi.bvec,/input/sub-1000/rev_b0.nii.gz
```

### Multiple subjects in the same pipeline run.

The `subject` identifiers let the pipeline know which subjects the files linked to. If you want to process multiple subjects, simply add more rows with their subject identifier and path to their input files.

```csv title="samplesheet.csv"
subject,t1,t2,dwi,bval,bvec,rev_b0,labels,wmparc,trk,peaks,fodf,mat,warp,metrics
sub-1000,/input/sub-1000/t1.nii.gz,/input/sub-1000/dwi.nii.gz,/input/sub-1000/dwi.bval,/input/sub-1000/dwi.bvec,/input/sub-1000/rev_b0.nii.gz
sub-1001,/input/sub-1001/t1.nii.gz,/input/sub-1001/dwi.nii.gz,/input/sub-1001/dwi.bval,/input/sub-1001/dwi.bvec,/input/sub-1001/rev_b0.nii.gz
```

### Specifying a samplesheet for a different profile

As mentioned above, the pipeline has various profiles that performs different tasks. The following tables will specify which inputs are required for every possible combination of profiles. Once you gathered all your required inputs, simply add their paths in the correct column of the samplesheet. **If the combination you want to run is not specified, feel free to raise an issue.**

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

#### **`-profile freesurfer`**

| Column    | Description                                                                                   |
| --------- | --------------------------------------------------------------------------------------------- |
| `subject` | Custom subject name. Spaces in sample names are automatically converted to underscores (`_`). |
| `t1`      | Full path to the T1w file. File has to be in the nifti file format (`.nii` or `.nii.gz`).     |

#### **`-profile tracking,freesurfer`** or **`-profile tracking,freesurfer,connectomics`**

| Column    | Description                                                                                                                                                                                                              |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `subject` | Custom subject name. Spaces in sample names are automatically converted to underscores (`_`).                                                                                                                            |
| `t1`      | Full path to the T1w file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                                                                                |
| `dwi`     | Full path to the DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                                                                                |
| `bval`    | Full path to the file containing the b-values.                                                                                                                                                                           |
| `bvec`    | Full path to the file containing the b-vectors.                                                                                                                                                                          |
| `rev_b0`  | Full path to the reverse-phase encoded DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                                                          |
| `metrics` | Full path to the **folder** containing additional metrics. Files within this folder has to be in the nifti file format (`.nii` or `.nii.gz`). **Optional, can only be supplied if `-profile connectomics` is selected.** |

#### **`-profile connectomics,freesurfer`**

| Column    | Description                                                                                                                                                |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `subject` | Custom subject name. Spaces in sample names are automatically converted to underscores (`_`).                                                              |
| `t1`      | Full path to the T1w file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                  |
| `dwi`     | Full path to the DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                  |
| `bval`    | Full path to the file containing the b-values.                                                                                                             |
| `bvec`    | Full path to the file containing the b-vectors.                                                                                                            |
| `trk`     | Full path to the whole-brain tractogram. File has to be in the `.trk` file format.                                                                         |
| `peaks`   | Full path to the file containing the fODF peaks. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                            |
| `fodf`    | Full path to the fODF file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                 |
| `mat`     | Full path to the affine transform required to register your anatomical image to the diffusion space.                                                       |
| `warp`    | Full path to the warp transform required to register your anatomical image to the diffusion space.                                                         |
| `metrics` | Full path to the **folder** containing additional metrics. Files within this folder has to be in the nifti file format (`.nii` or `.nii.gz`). **Optional** |

#### **`-profile connectomics`** or **`-profile connectomics,infant`**

| Column       | Description                                                                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `subject`    | Custom subject name. Spaces in sample names are automatically converted to underscores (`_`).                                                              |
| `t1` or `t2` | Full path to the T1w/T2w file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                              |
| `dwi`        | Full path to the DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                  |
| `bval`       | Full path to the file containing the b-values.                                                                                                             |
| `bvec`       | Full path to the file containing the b-vectors.                                                                                                            |
| `labels`     | Full path to the file containing your labels to use in the segmentation. File has to be in the nifti file format (`.nii` or `.nii.gz`).                    |
| `trk`        | Full path to the whole-brain tractogram. File has to be in the `.trk` file format.                                                                         |
| `peaks`      | Full path to the file containing the fODF peaks. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                            |
| `fodf`       | Full path to the fODF file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                                                 |
| `mat`        | Full path to the affine transform required to register your anatomical image to the diffusion space.                                                       |
| `warp`       | Full path to the warp transform required to register your anatomical image to the diffusion space.                                                         |
| `metrics`    | Full path to the **folder** containing additional metrics. Files within this folder has to be in the nifti file format (`.nii` or `.nii.gz`). **Optional** |

#### **`-profile tracking,infant`**

| Column    | Description                                                                                                     |
| --------- | --------------------------------------------------------------------------------------------------------------- |
| `subject` | Custom subject name. Spaces in sample names are automatically converted to underscores (`_`).                   |
| `t2`      | Full path to the T2w file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                       |
| `dwi`     | Full path to the DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                       |
| `bval`    | Full path to the file containing the b-values.                                                                  |
| `bvec`    | Full path to the file containing the b-vectors.                                                                 |
| `rev_b0`  | Full path to the reverse-phase encoded DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`). |
| `wmparc`  | Full path to the WM mask file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                   |

#### **`-profile tracking,connectomics,infant`**

| Column    | Description                                                                                                                             |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `subject` | Custom subject name. Spaces in sample names are automatically converted to underscores (`_`).                                           |
| `t2`      | Full path to the T2w file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                               |
| `dwi`     | Full path to the DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                               |
| `bval`    | Full path to the file containing the b-values.                                                                                          |
| `bvec`    | Full path to the file containing the b-vectors.                                                                                         |
| `rev_b0`  | Full path to the reverse-phase encoded DWI file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                         |
| `labels`  | Full path to the file containing your labels to use in the segmentation. File has to be in the nifti file format (`.nii` or `.nii.gz`). |
| `wmparc`  | Full path to the WM mask file. File has to be in the nifti file format (`.nii` or `.nii.gz`).                                           |

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run scilus/nf-pediatric -r main --input ./samplesheet.csv --outdir ./results -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run scilus/nf-pediatric -r main -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull scilus/nf-pediatric
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-pediatric releases page](https://github.com/nf/pediatric/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, and Apptainer) - see below.

> [!NOTE]
> We highly recommend the use of Docker/Singularity/Apptainer containers for full pipeline reproducibility, however when this is not possible, you can run it locally if you have the required softwares installed.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `no_symlink`
  - By default, the pipeline used symlink to create the files in the output directory. By using this profile, files will be copied from the work directory into the specified output directory.
- `slurm`
  - A generic configuration profile for use on SLURM managed clusters.
- `arm`
  - A generic configuration profile for ARM based computers.
- `tracking`
  - Perform DWI preprocessing, DTI and FODF modelling, anatomical segmentation, and tractography. Final outputs are the DTI/FODF metric maps, whole-brain tractogram, registered anatomical image, etc.
- `freesurfer`
  - Run FreeSurfer or FastSurfer for T1w surface reconstruction. Then, the [Brainnetome Child Atlas](https://academic.oup.com/cercor/article/33/9/5264/6762896) is mapped to the subject space. **Not available with the `infant` profile.**
- `connectomics`
  - Perform tractogram segmentation according to an atlas, tractogram filtering, and compute metrics. Final outputs are connectivity matrices.
- `infant`
  - This profile adapt some processing steps to infant data, but also requires more input files. See below for a list of the required files.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original). If it still fails after the second attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
