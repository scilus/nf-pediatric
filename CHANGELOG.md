# nf-pediatric: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - [2025-01-08]

### `Added`

- Required --dti_shells and --fodf_shells parameters.

### `Changed`

- Fastsurfer and freesurfer outputs are now in their own dedicated output folder.

## [Unreleased] - [2024-12-23]

### `Added`

- Update minimal `nextflow` version to 24.10.0.
- Add subject and global-level QC using the MultiQC module.
- If `-profile freesurfer` is used, do not run T1 preprocessing.
- Optional DWI preprocessing using parameters.
- New docker containers for fastsurfer, atlases, and QC.
- Transform computation in `segmentation/fastsurfer`.

## [Unreleased] - [2024-11-21]

### `Added`

- Complete test suites for the pipeline using stub-runs.
- Complete port of [Infant-DWI](https://github.com/scilus/Infant-DWI/) modules and workflows into the nf-core template.
