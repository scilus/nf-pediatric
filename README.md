# nf-pediatric

[![nf-pediatric CI](https://github.com/scilus/nf-pediatric/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/scilus/nf-pediatric/actions/workflows/ci.yml) [![nf-core linting](https://github.com/scilus/nf-pediatric/actions/workflows/linting.yml/badge.svg?branch=main)](https://github.com/scilus/nf-pediatric/actions/workflows/linting.yml) [![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com) [![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.2-23aa62.svg)](https://www.nextflow.io/) [![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/) [![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**nf-pediatric** is an end-to-end connectomics pipeline for pediatric (0-18y) dMRI and sMRI brain scans. It performs tractography, t1 reconstruction, cortical and subcortical segmentation, and connectomics. Final outputs are connectivity matrices for a variety of diffusion (or not) related metrics.

![nf-pediatric-schema](/assets/nf-pediatric-schema.svg)

A detailed description of the minimal outputs can be found [here](/docs/output.md).

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

The pipeline required input is in the form of a samplesheet containing the path to all your input files for all your subjects. For the most basic usage (`-profile tracking`), your input samplesheet should look like this:

`samplesheet.csv`:

```csv
subject,t1,t2,dwi,bval,bvec,rev_b0,labels,wmparc,trk,peaks,fodf,mat,warp,metrics
sub-1000,/input/sub-1000/t1.nii.gz,/input/sub-1000/dwi.nii.gz,/input/sub-1000/dwi.bval,/input/sub-1000/dwi.bvec,/input/sub-1000/rev_b0.nii.gz
```

Each row represents a subject, and each column represent a specific file that can be passed as an input.

Now, you can run the pipeline using:

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
