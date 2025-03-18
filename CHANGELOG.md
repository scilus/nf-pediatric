# nf-pediatric: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - [2025-03-18]

### `Added`

- Option to output results (metrics map, tractogram, labels, ...) to a template space (leveraging TemplateFlow).

## [Unreleased] - [2025-03-03]

### `Fixed`

- Output `.annot` and `.stats` file for brainnetome in FS output ([#19](https://github.com/scilus/nf-pediatric/issues/19))
- Resampling/reshaping according to input file when registering brainnetome atlas ([#26](https://github.com/scilus/nf-pediatric/issues/26))

## [Unreleased] - [2025-02-28]

### `Added`

- QC for eddy, topup, and registration processes.
- More verbose description of each MultiQC section.

### `Fixed`

- Completed the addition of QC in pipeline ([#7](https://github.com/scilus/nf-pediatric/issues/7))
- Move cerebellum and hypothalamus sub-segmentation as optional steps in fastsurfer ([#23](https://github.com/scilus/nf-pediatric/issues/23))

## [Unreleased] - [2025-02-14]

### `Changed`

- Replace local modules by their `nf-neuro` equivalent.
- Update modules according to latest version of `nf-neuro` (commit: fc357476ff69fa206f241f77f3f5517daa06b91e)

## [Unreleased] - [2025-02-12]

### `Added`

- BIDS folder as mandatory input ([#16](https://github.com/scilus/nf-pediatric/issues/16)).
- New test datasets (BIDS input folder and derivatives).
- Support BIDS derivatives as input for `-profile connectomics`.
- T2w image for pediatric data are now preprocessed and coregistered in T1w space.

### `Changed`

- `synthstrip` is now the default brain extraction method.
- Bump `nf-core` version to `3.2.0`.

### `Removed`

- Samplesheet input is not longer supported. Using BIDS folder now.

## [Unreleased] - [2025-01-22]

### `Fixed`

- Files coming from Phillips scanner had unvalid datatypes making topup/eddy correction creating weird artifacts. Now files are converted to `--data_type float32`.
- Added build information to fastsurfer container.

## [Unreleased] - [2025-01-20]

### `Added`

- New testing file for anatomical preprocessing and surface reconstruction of infant data.
- New module for formatting of Desikan-Killiany atlas (for infant).
- Output of tissue-specific `fodf` maps in BIDS output.
- Anatomical preprocessing pipeline for infant data using M-CRIB-S and Infant FS.
- Coregistration of T2w and T1w if both available for the infant profile.
- New docker image for infant anatomical segmentation and surface reconstruction (M-CRIB-S and Infant FS)
- Required --dti_shells and --fodf_shells parameters.

### `Fixed`

- Wrong data type for phillips scanners prior to topup.
- Structural segmentation pipeline for infant data. (#3)
- Correctly set `fastsurfer` version in docker container.

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
