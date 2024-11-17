#! /usr/bin/env python3.7

"""
"""
import argparse
import json
import os

from dipy.io.utils import is_header_compatible
import nibabel as nib
import numpy as np

from scilpy.utils.filenames import split_name_with_nii
from scilpy.io.utils import (add_overwrite_arg,
                             assert_inputs_exist,
                             assert_output_dirs_exist_and_empty)


def buildArgsParser():

    p = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter,
                                description=__doc__)
    p.add_argument('in_img', nargs='+',
                   help='Input list of images')
    p.add_argument('in_json',
                   help='Dictionary of filename.')
    p.add_argument('out_dir',
                   help='Output folder.')
    add_overwrite_arg(p)
    return p


def main():
    parser = buildArgsParser()
    args = parser.parse_args()

    assert_inputs_exist(parser, [args.in_json] + args.in_img)
    assert_output_dirs_exist_and_empty(parser, args, args.out_dir,
                                       create_dir=True)

    with open(args.in_json, 'r') as f:
        dict_name = json.load(f)

    ref_img = nib.load(args.in_img[0])

    for filename in args.in_img:
        basename, _ = split_name_with_nii(os.path.basename(filename))

        if basename not in dict_name:
            print(basename, 'not in dictionnary!')
            continue

        img = nib.load(filename)
        if not is_header_compatible(ref_img, img):
            parser.error('Header not compatible for {}'.format(filename))

        data = img.get_fdata().astype(np.uint16)
        value = dict_name[basename]
        outname = os.path.join(args.out_dir, '{}.nii.gz'.format(value))

        data *= int(value)
        nib.save(nib.Nifti1Image(data, img.affine, header=img.header),
                 outname)


if __name__ == "__main__":
    main()
