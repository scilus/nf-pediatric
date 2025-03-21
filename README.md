# nf-pediatric

[![nf-pediatric CI](https://github.com/scilus/nf-pediatric/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/scilus/nf-pediatric/actions/workflows/ci.yml) [![nf-core linting](https://github.com/scilus/nf-pediatric/actions/workflows/linting.yml/badge.svg?branch=main)](https://github.com/scilus/nf-pediatric/actions/workflows/linting.yml) [![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com) [![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.10.0-23aa62.svg)](https://www.nextflow.io/) [![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/) [![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**nf-pediatric** is an end-to-end connectomics pipeline for pediatric (0-18y) dMRI and sMRI brain scans. It performs preprocessing, tractography, t1 reconstruction, cortical and subcortical segmentation, and connectomics.

![nf-pediatric-schema](/assets/nf-pediatric-schema.svg)

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

`nf-pediatric` core functionalities are accessed and selected using profiles. This means users can select which part of the pipeline they want to run depending on their specific aims and the current state of their data (already preprocessed or not). As of now, here is a list of the available profiles and a short description of their processing steps:

**Processing profiles**:

1. `-profile segmentation`: By selecting this profile, [FreeSurfer `recon-all`](https://surfer.nmr.mgh.harvard.edu/), [FastSurfer](https://deep-mi.org/research/fastsurfer/) or [M-CRIB-S/InfantFS](https://github.com/DevelopmentalImagingMCRI/MCRIBS) will be used to process the T1w/T2w images and the Brainnetome Child Atlas ([Li et al., 2022](https://doi.org/10.1093/cercor/bhac415)) or Desikan-Killiany (for infant) will be registered using surface-based methods in the native subject space.
1. `-profile tracking`: This is the core profile behind `nf-pediatric`. By selecting it, DWI data will be preprocessed (denoised, corrected for distortion, normalized, resampled, ...). In parallel, T1w will be preprocessed (if `-profile segmentation` is not selected), registered into diffusion space, and segmented to extract tissue masks/maps. Preprocessed DWI data will be used to fit both the DTI and fODF models. As the final step, whole-brain tractography will be performed using either local tracking or particle filter tracking (PFT).
1. `-profile connectomics`: By selecting this profiles, labels will be registered in diffusion space and used to segment the tractogram into individual connections. The segmented tractogram will then be filtered, using [COMMIT](https://github.com/daducci/COMMIT) to remove false positive streamlines. Following filtering, connectivity matrices will be computed for a variety of metrics and outputted as numpy arrays usable for further statistical analysis.
1. `-profile infant`: As opposed to the other profiles, the `infant` profile does not enable a specific block of processing steps (although various steps are changed compared to the default pipeline), but will change various configs and parameters to adapt the existing profile for infant data (<2 years). This profile is made to be used in conjunction with the others.

**Configuration profiles**:

1. `-profile docker`: Each process will be run using docker containers (**Recommended**).
1. `-profile apptainer` or `-profile singularity`: Each process will be run using apptainer/singularity images (**Recommended**).
1. `-profile arm`: Made to be use on computers with an ARM architecture. **This is still experimental, depending on which profile you select, some containers might not be built for the ARM architecture. Feel free to open an issue if needed.**
1. `-profile no_symlink`: By default, the results directory contains symlink to files within the `work` directory. By selecting this profile, results will be copied from the work directory without the use of symlinks.
1. `-profile slurm`: If selected, the SLURM job scheduler will be used to dispatch jobs. **Please note that, by using this profile, you might have to adapt the config files to your specific computer nodes architecture.**

**Using either `-profile docker` or `-profile apptainer` is highly recommended, as it controls the version of the software used and avoids the installation of all the required softwares.**

For example, to perform the end-to-end connectomics pipeline, users should select `-profile tracking,segmentation,connectomics` for pediatric data and `-profile infant,tracking,segmentation,connectomics` for infant data. In addition to profile selection, users can change default parameters using command line arguments at runtime. To view a list of the parameters that can be customized, use the `--help` argument as follow:

```bash
nextflow run scilus/nf-pediatric -r main --help
```

### Input specification

For complete usage instructions, please see the [documentation](/docs/usage.md). **nf-pediatric** aligns with the [BIDS](https://bids-specification.readthedocs.io/en/stable/) specification. To promote the use of standardized data formats and structures, **nf-pediatric** requires a BIDS-compliant folder as its input directories. We encourage users to validate their BIDS layout using the [bids-validator tool](https://hub.docker.com/r/bids/validator). The following example provides a BIDS structure for pediatric data (not infant) containg an acquisition with a reverse phase-encoded B0 image.

```bash
<bids_folder>
  |- sub-XXXX
  | |- ses-session
  | | |- anat
  | | | |- sub-XXXX_*_T1w.nii.gz
  | | | └- sub-XXXX_*_T1w.json
  | | |- dwi
  | | | |- sub-XXXX_*_dwi.nii.gz
  | | | |- sub-XXXX_*_dwi.json
  | | | |- sub-XXXX_*_dwi.bval
  | | | └- sub-XXXX_*_dwi.bvec
  | | |- fmap
  | | | |- sub-XXXX_*_epi.nii.gz
  | | | └- sub-XXXX_*_epi.json
  └- sub-YYYY
    <...>
```

Once your input directory is validated with the [bids-validator tool](https://hub.docker.com/r/bids/validator), the pipeline has only four required parameters that need to be supplied at runtime: `--outdir`, `--input`, `--dti_shells`, and `--fodf_shells`. Now, you can run the pipeline using:

```bash
nextflow run scilus/nf-pediatric \
    -r main \
    -profile <selected_profiles> \
    --input <BIDS_folder> \
    --outdir <your_outdir> \
    --dti_shells "0 1500" \ # Replace with the shells you want to use for DTI fitting.
    --fodf_shells "1000 2000 3000" # Replace with the desired shells.
```

There is no need to `git clone` the pipeline prior to lauching it, **nextflow will do it for you!** Additional information on running multiple profiles and the infant profile can be found [here](/docs/usage.md).

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Outputs of `nf-pediatric`

By default, `nf-pediatric` outputs only the final preprocessed files and leave out all the intermediate steps to avoid generating too many files, which can become a problem on some clusters. The output folder consists of per subject BIDS-like directories, containing the `anat`, `dwi`, `multiqc`, and `figures` subfolders. For a detailed description of the output structure, please see [the documentation](/docs/output.md).

## Using `nf-pediatric` on computer nodes without internet access.

Some computing nodes does not have access to internet at runtime. Since the pipeline interacts with the containers repository and pull during execution, it won't work if the nodes do not have access to the internet. Fortunately, containers can be downloaded prior to the pipeline execution, and fetch locally during runtime. Using `nf-core` tools (for a detailed installation guide, see the [nf-core documentation](https://nf-co.re/docs/nf-core-tools/installation)), we can use the [`nf-core pipelines download`](https://nf-co.re/docs/nf-core-tools/pipelines/download#downloading-apptainer-containers) command. To view the options before the download, you can use `nf-core pipelines download -h`. To use the prompts, simply run `nf-core pipelines download` as follows (_downloading all containers takes ~15 minutes but requires a fair amount of local disk space_):

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
