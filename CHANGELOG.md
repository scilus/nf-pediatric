# nf-pediatric: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### `Added`

- New testing file for anatomical preprocessing and surface reconstruction of infant data.
- New module for formatting of Desikan-Killiany atlas (for infant).
- Output of tissue-specific `fodf` maps in BIDS output.
- Anatomical preprocessing pipeline for infant data using M-CRIB-S and Infant FS.
- Coregistration of T2w and T1w if both available for the infant profile.
- New docker image for infant anatomical segmentation and surface reconstruction (M-CRIB-S and Infant FS)
- Required --dti_shells and --fodf_shells parameters.

### `Fixed`

- Structural segmentation pipeline for infant data. (#3)

### `Changed`

- Bump `nf-core` version to `3.1.2`.
- Refactored `-profile freesurfer` to `-profile segmentation`.
- Config files have been moved from the `modules.config` into themed config files for easier maintainability.
- Fastsurfer and freesurfer outputs are now in their own dedicated output folder.

### `Removed`

- Custom atlas name parameter until the use of custom atlas is enabled.
- White matter mask and labels files as required inputs since they can now be computed for all ages.

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
