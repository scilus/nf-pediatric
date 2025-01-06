# nf-pediatric

[![nf-pediatric CI](https://github.com/scilus/nf-pediatric/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/scilus/nf-pediatric/actions/workflows/ci.yml) [![nf-core linting](https://github.com/scilus/nf-pediatric/actions/workflows/linting.yml/badge.svg?branch=main)](https://github.com/scilus/nf-pediatric/actions/workflows/linting.yml) [![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com) [![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.10.0-23aa62.svg)](https://www.nextflow.io/) [![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/) [![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**nf-pediatric** is an end-to-end connectomics pipeline for pediatric (0-18y) dMRI and sMRI brain scans. It performs tractography, t1 reconstruction, cortical and subcortical segmentation, and connectomics. Final outputs are connectivity matrices for a variety of diffusion (or not) related metrics.

![nf-pediatric-schema](/assets/nf-pediatric-schema.svg)

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

`nf-pediatric` core functionalities are accessed and selected using profiles. This means users can select which part of the pipeline they want to run depending on their specific aims and the current state of their data (already preprocessed or not). Depending on your selection, the mandatory inputs will change, please see the [inputs](/docs/usage.md) documentation for a comprehensive overview for each profile. As of now, here is a list of the available profiles and a short description of their processing steps:

**Processing profiles**:

1. `-profile freesurfer`: By selecting this profile, [FreeSurfer `recon-all`](https://surfer.nmr.mgh.harvard.edu/) or [FastSurfer](https://deep-mi.org/research/fastsurfer/) will be used to process the T1w images and the Brainnetome Child Atlas ([Li et al., 2022](https://doi.org/10.1093/cercor/bhac415)) will be registered using surface-based methods in the native subject space.
1. `-profile tracking`: This is the core profile behind `nf-pediatric`. By selecting it, DWI data will be preprocessed (denoised, corrected for distortion, normalized, resampled, ...). In parallel, T1 will be preprocessed (if `-profile freesurfer` is not selected), registered into diffusion space, and segmented to extract tissue masks. Preprocessed DWI data will be used to fit both the DTI and fODF models. As the final step, whole-brain tractography will be performed using either local tracking or particle filter tracking (PFT).
1. `-profile connectomics`: By selecting this profiles, the whole-brain tractogram will be filtered to remove false positive streamlines, labels will be registered in diffusion space and used to segment the tractogram into individual connections. Following segmentation, connectivity matrices will be computed for a variety of metrics and outputted as numpy arrays usable for further statistical analysis.
1. `-profile infant`: As opposed to the other profiles, the `infant` profile does not enable a specific block of processing steps, but will change various configs and parameters to adapt the existing profile for infant data (<2 years). This profile is made to be used in conjunction with the others (with the exception of `-profile freesurfer` which is unavailable for infant data for now).

**Configuration profiles**:

1. `-profile docker`: Each process will be run using docker containers.
1. `-profile apptainer` or `-profile singularity`: Each process will be run using apptainer/singularity images.
1. `-profile arm`: Made to be use on computers with an ARM architecture.
1. `-profile no_symlink`: By default, the results directory contains symlink to files within the `work` directory. By selecting this profile, results will be copied from the work directory without the use of symlinks.
1. `-profile slurm`: If selected, the SLURM job scheduler will be used to dispatch jobs.

**Using either `-profile docker` or `-profile apptainer` is highly recommended, as it controls the version of the software used and avoids the installation of all the required softwares.**

For example, to perform the end-to-end connectomics pipeline, users should select `-profile tracking,freesurfer,connectomics` for pediatric data and `-profile infant,tracking,connectomics` for infant data. Once you selected your profile, you can check which input files are mandatory [here](/docs/usage.md). In addition to profile selection, users can change default parameters using command line arguments at runtime. To view a list of the parameters that can be customized, use the `--help` argument as follow:

```bash
nextflow run scilus/nf-pediatric -r main --help
```

### Input specification

The pipeline required input is in the form of a samplesheet (.csv file) containing the path to all your input files for all your subjects (for more details regarding which files are mandatory for each profile, see [here](/docs/usage.md)). For the most basic usage (`-profile tracking`), your input samplesheet should look like this:

`samplesheet.csv`:

```csv
subject,t1,t2,dwi,bval,bvec,rev_b0,labels,wmparc,trk,peaks,fodf,mat,warp,metrics
sub-1000,/input/sub-1000/t1.nii.gz,/input/sub-1000/dwi.nii.gz,/input/sub-1000/dwi.bval,/input/sub-1000/dwi.bvec,/input/sub-1000/rev_b0.nii.gz
```

Each row represents a subject, and each column represent a specific file that can be passed as an input. **It is mandatory that the samplesheet has all the headers, even if some files are not provided as inputs.** To avoid creating this samplesheet by hand, you can script it using a simple bash script that matches your input folder structure. For an example, see the [`assemble_samplesheet.sh`](/assets/assemble_samplesheet.sh) example (modify it according to your needs). Once this is done, the pipeline has only two required parameters that need to be supplied at runtime: `--outdir` and `--input`. Now, you can run the pipeline using:

```bash
nextflow run scilus/nf-pediatric \
    -r main \
    -profile docker,tracking \
    --input samplesheet.csv \
    --outdir <your_outdir>
```

With this command, you will run the `tracking` profile for non-infant data. There is no need to `git clone` the pipeline prior to lauching it, **nextflow will do it for you!** Additional information on running multiple profiles and the infant profile can be found [here](/docs/usage.md).

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Outputs of `nf-pediatric`

By default, `nf-pediatric` outputs only the final preprocessed files and leave out all the intermediate steps to avoid generating too many files, which can become a problem on some clusters. The output folder consists of per subject BIDS-like directories, containing the `anat`, `dwi`, `multiqc`, and `figures` subfolders. For a detailed description of the output structure, please see [the documentation](/docs/output.md).

## Using `nf-pediatric` on computer nodes without internet access.

Some computing nodes does not have access to internet at runtime. Since the pipeline interacts with the containers repository and pull during execution, it won't work if the nodes do not have access to the internet. Fortunately, containers can be downloaded prior to the pipeline execution, and fetch locally during runtime. Using `nf-core` tools (for a detailed installation guide, see the [nf-core documentation](https://nf-co.re/docs/nf-core-tools/installation)), we can use the [`nf-core pipelines download`](https://nf-co.re/docs/nf-core-tools/pipelines/download#downloading-apptainer-containers) command. To view the options before the download, you can use `nf-core pipelines download -h`. To use the prompts, simply run `nf-core pipelines download` as follows (_downloading all containers takes ~15 minutes_):

```bash
$ nf-core pipelines download -l docker.io


                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\
    |\ | |__  __ /  ` /  \ |__) |__         }  {
    | \| |       \__, \__/ |  \ |___     \`-._,-`-,
                                          `._,._,'

    nf-core/tools version 3.1.1 - https://nf-co.re


Specify the name of a nf-core pipeline or a GitHub repository name (user/repo).
? Pipeline name: scilus/nf-pediatric
WARNING  Could not find GitHub authentication token. Some API requests may fail.
? Select release / branch: main  [branch]

If you are working on the same system where you will run Nextflow, you can amend the downloaded images to the ones in the$NXF_SINGULARITY_CACHEDIR folder,
Nextflow will automatically find them. However if you will transfer the downloaded files to a different system then they should be copied to the target
folder.
? Copy singularity images from $NXF_SINGULARITY_CACHEDIR to the target folder or amend new images to the cache? copy

If transferring the downloaded files to another system, it can be convenient to have everything compressed in a single file.
This is not recommended when downloading Singularity images, as it can take a long time and saves very little space.
? Choose compression type: none
INFO     Saving 'scilus/nf-pediatric'
          Pipeline revision: 'main'
          Use containers: 'singularity'
          Container library: 'docker.io'
          Using $NXF_SINGULARITY_CACHEDIR': /home/gagnona/test-download'
          Output directory: 'scilus-nf-pediatric_main'
          Include default institutional configuration: 'False'
INFO     Downloading workflow files from GitHub
```

**Once all images are downloaded, you need to set `NXF_SINGULARITY_CACHEDIR` to the directory in which you downloaded the images. You can either include it in your `.bashrc` or export it prior to launching the pipeline.**

## Credits

nf-pediatric was originally written by Anthony Gagnon.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
