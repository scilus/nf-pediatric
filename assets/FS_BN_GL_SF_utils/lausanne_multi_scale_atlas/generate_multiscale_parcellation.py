#!/usr/bin/env python3
# encoding: utf-8

"""
This function applies the Multi-scale Lausanne2008 Parcellation to an input
subject brain. The output of FreeSurfer recon-all is required.

For more information concerning the Multi-scale Lausanne2008 Parcellation,
please refer to L. Cammoun et al., Mapping the human connectome at multiple
scales with diffusion spectrum MRI, J. Neurosci. Methods 2012, 203(2):386-397

This script generates the Lausanne2008 multiscale parcellation for an input
subject SUBJECT_ID. It is assumed that the input subject has been processed
with FREESURFER standard pipeline, i.e its recon-all output is available.

A SUBJECT_ID folder must exist in the FREESURFER subjects directory ($SUBJECTS_DIR).
Before running this script, you must copy the multiscale-atlas fsaverage
annotation files from the CONNECTOME_ATLAS folder, to your local
FREESURFER $SUBJECTS_DIR/fsaverage/label/ folder.
"""


import argparse
import logging
import os
import subprocess

import nibabel as nib
import numpy as np


def _build_arg_parser():

    p = argparse.ArgumentParser(
        formatter_class=argparse.RawTextHelpFormatter,
        description=__doc__)
    p.add_argument('subj_dir',
                   help='Your local FreeSurfer subjects directory.')
    p.add_argument('subj_id',
                   help='Input subject ID.')
    p.add_argument('fs_home',
                   help='Your local FreeSurfer home directory.')
    p.add_argument('--scale', type=int, choices=[1, 2, 3, 4, 5],
                   help='Choose the scale at which to compute the atlas.')
    p.add_argument('--dilation_factor', default=2, type=int,
                   help='mri_aparc2aseg option for dilated cortical maps:\n'
                   'Maximum distance (mm) from cortex to be labeld as '
                   '[%(default)s]')
    p.add_argument('--log_level', default='INFO',
                   choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                   help='Log level of the logging class.')

    return p


def main():

    # 0. Handle inputs
    parser = _build_arg_parser()
    args = parser.parse_args()

    logging.basicConfig(level=args.log_level)

    freesurfer_home = args.fs_home
    freesurfer_home = os.path.abspath(freesurfer_home)
    if not (os.path.isdir(freesurfer_home)):
        parser.error('FreeSurfer home directory does not exist')
    logging.info('- FreeSurfer home directory: {}'.format(freesurfer_home))

    freesurfer_subj = args.subj_dir
    freesurfer_subj = os.path.abspath(freesurfer_subj)
    if not (os.path.isdir(freesurfer_subj)
            and os.path.isdir(os.path.join(freesurfer_subj, 'fsaverage'))):
        parser.error('FreeSurfer subject directory is invalid.\n'
                     'The folder does not exist or does not contain fsaverage/')

    subject_id = args.subj_id
    subject_dir = os.path.join(freesurfer_subj, subject_id)
    if not (os.path.isdir(subject_dir)):
        parser.error('No directory for the subject id was found')

    logging.info('- Input subject id: {}'.format(subject_id))
    logging.info('- FreeSurfer subject directory: {}'.format(freesurfer_subj))

    # Multiscale parcellation - define annotation and segmentation variables
    rh_annot_files = ['rh.lausanne2008.scale1.annot',
                      'rh.lausanne2008.scale2.annot',
                      'rh.lausanne2008.scale3.annot',
                      'rh.lausanne2008.scale4.annot',
                      'rh.lausanne2008.scale5.annot']
    lh_annot_files = ['lh.lausanne2008.scale1.annot',
                      'lh.lausanne2008.scale2.annot',
                      'lh.lausanne2008.scale3.annot',
                      'lh.lausanne2008.scale4.annot',
                      'lh.lausanne2008.scale5.annot']
    annot = ['lausanne2008.scale1',
             'lausanne2008.scale2',
             'lausanne2008.scale3',
             'lausanne2008.scale4',
             'lausanne2008.scale5']
    aseg_output = ['lausanne2008.scale1+aseg.nii.gz',
                   'lausanne2008.scale2+aseg.nii.gz',
                   'lausanne2008.scale3+aseg.nii.gz',
                   'lausanne2008.scale4+aseg.nii.gz',
                   'lausanne2008.scale5+aseg.nii.gz']

    # Number of scales in multiscale parcellation
    if args.scale is None:
        nscales = range(0, 5)
    else:
        nscales = [args.scale-1]

    # Freesurfer IDs for subcortical structures and brain stem
    lh_sub = np.array([10, 11, 12, 13, 26, 17, 18])
    rh_sub = np.array([49, 50, 51, 52, 58, 53, 54])
    brain_stem = np.array([16])

    # Check existence of multiscale atlas fsaverage annot files
    for i in nscales:
        for hemi in [lh_annot_files, rh_annot_files]:
            this_file = os.path.join(freesurfer_subj, 'fsaverage', 'label',
                                     hemi[i])
            if not os.path.isfile(this_file):
                parser.error('{} is required! Please, copy the annot files FROM \n'
                             '\'connectome_atlas/misc/multiscale_parcellation/fsaverage/label\' '
                             'TO your FreeSurfer \'$SUBJECTS_DIR/fsaverage/label\' folder'.format(this_file))

    # Check existence of tmp folder in input subject folder
    this_dir = os.path.join(subject_dir, 'tmp')
    if not (os.path.isdir(this_dir)):
        os.makedirs(this_dir)

    # We need to add these instructions when running FreeSurfer commands from Python
    fs_string = 'export FREESURFER_HOME={}; . $FREESURFER_HOME/SetUpFreeSurfer.sh; export SUBJECTS_DIR={}'.format(
        freesurfer_home, freesurfer_subj)

    # Redirect ouput if low verbose
    FNULL = open(os.devnull, 'w')

    # Loop over parcellation scales
    for i in nscales:
        logging.info('Computing parcellation, scale #{}'.format(i+1))

        # 1. Resample fsaverage CorticalSurface onto SUBJECT_ID CorticalSurface and map annotation for current scale
        # Left hemisphere
        logging.info('     > resample fsaverage LeftCorticalSurface to '
                     'individual CorticalSurface')
        mri_cmd = '{}; mri_surf2surf --srcsubject fsaverage --trgsubject {} --hemi lh --sval-annot {} --tval {}'.format(
            fs_string,
            subject_id,
            os.path.join(freesurfer_subj, 'fsaverage',
                         'label', lh_annot_files[i]),
            os.path.join(subject_dir, 'label', lh_annot_files[i]))
        if args.log_level == 'DEBUG':
            _ = subprocess.call(mri_cmd, shell=True)
        else:
            _ = subprocess.call(mri_cmd, shell=True,
                                stdout=FNULL, stderr=subprocess.STDOUT)

        # Right hemisphere
        logging.info('     > resample fsaverage RightCorticalSurface to '
                     'individual CorticalSurface')
        mri_cmd = '{}; mri_surf2surf --srcsubject fsaverage --trgsubject {} --hemi rh --sval-annot {} --tval {}'.format(
            fs_string,
            subject_id,
            os.path.join(freesurfer_subj, 'fsaverage',
                         'label', rh_annot_files[i]),
            os.path.join(subject_dir, 'label', rh_annot_files[i]))
        if args.log_level == 'DEBUG':
            _ = subprocess.call(mri_cmd, shell=True)
        else:
            _ = subprocess.call(mri_cmd, shell=True,
                                stdout=FNULL, stderr=subprocess.STDOUT)

        # 2. Generate Nifti volume from annotation
        #    Note: change here --wmparc-dmax (FS default 5mm) to dilate cortical regions toward the WM
        logging.info('     > generate Nifti volume from annotation')
        mri_cmd = '{}; mri_aparc2aseg --s {} --annot {} --wmparc-dmax {} --labelwm --hypo-as-wm --new-ribbon --o {}'.format(
            fs_string,
            subject_id,
            annot[i],
            args.dilation_factor,
            os.path.join(subject_dir, 'tmp', aseg_output[i]))
        if args.log_level == 'DEBUG':
            _ = subprocess.call(mri_cmd, shell=True)
        else:
            _ = subprocess.call(mri_cmd, shell=True,
                                stdout=FNULL, stderr=subprocess.STDOUT)

        # 3. Update numerical IDs of cortical and subcortical regions
        # Load Nifti volume
            logging.info('     > relabel cortical and subcortical regions')

        this_nifti = nib.load(os.path.join(subject_dir, 'tmp', aseg_output[i]))
        vol = this_nifti.get_fdata()
        hdr = this_nifti.header

        # Initialize output
        hdr2 = hdr.copy()
        hdr2.set_data_dtype(np.uint16)
        vol2 = np.zeros(this_nifti.shape, dtype=np.int16)

        # -------- Right hemisphere --------
        # Relabelling cortical regions (2000+)
        ii = np.where((vol > 2000) & (vol < 3000))
        vol2[ii] = vol[ii] - 2000
        # Relabelling Right hemisphere labeled-WM (4000+)
        if args.dilation_factor > 0:
            ii = np.where((vol > 4000) & (vol < 5000))
            vol2[ii] = vol[ii] - 4000
        nlabel = np.amax(vol2)

        # Relabelling Subcortical Right hemisphere
        # NOTE: skip numerical IDs which are used for the thalamic subcortical nuclei
        newLabels = np.concatenate((np.array([nlabel+1]),
                                    np.arange(nlabel+8,
                                              nlabel+len(rh_sub)+7)),
                                   axis=0)
        for j in range(0, len(rh_sub)):
            ii = np.where(vol == rh_sub[j])
            vol2[ii] = newLabels[j]
        nlabel = np.amax(vol2)

        # -------- Left hemisphere --------
        # Relabelling cortical regions (1000+)
        ii = np.where((vol > 1000) & (vol < 2000))
        vol2[ii] = vol[ii] - 1000 + nlabel
        # Relabelling Left hemisphere labeled-WM (3000+)
        if args.dilation_factor > 0:
            ii = np.where((vol > 3000) & (vol < 4000))
            vol2[ii] = vol[ii] - 3000 + nlabel
        nlabel = np.amax(vol2)

        # Relabelling Subcortical Right hemisphere
        # NOTE: skip numerical IDs which are used for the thalamic subcortical nuclei
        newLabels = np.concatenate((np.array([nlabel+1]),
                                    np.arange(nlabel+8,
                                              nlabel+len(rh_sub)+7)),
                                   axis=0)
        for j in range(0, len(lh_sub)):
            ii = np.where(vol == lh_sub[j])
            vol2[ii] = newLabels[j]
        nlabel = np.amax(vol2)

        # Relabelling Brain Stem
        ii = np.where(vol == brain_stem)
        vol2[ii] = nlabel + 1

        # 4. Save Nifti and mgz volumes
        logging.info('     > save output volumes')
        this_out = os.path.join(subject_dir, 'mri', aseg_output[i])
        img = nib.Nifti1Image(vol2, this_nifti.affine, hdr2)
        nib.save(img, this_out)
        mri_cmd = '{}; mri_convert -i {} -o {}'.format(
            fs_string,
            this_out,
            os.path.join(subject_dir, 'mri', aseg_output[i][0:-4]+'.mgz'))
        if args.log_level == 'DEBUG':
            _ = subprocess.call(mri_cmd, shell=True)
        else:
            _ = subprocess.call(mri_cmd, shell=True,
                                stdout=FNULL, stderr=subprocess.STDOUT)
        os.remove(os.path.join(subject_dir, 'tmp', aseg_output[i]))


if __name__ == "__main__":
    main()
