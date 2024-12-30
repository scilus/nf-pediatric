#!/bin/bash

# This script will assemble a samplesheet based on an input directory
# containing the required images files. While the script is designed to
# work with the default file names, it can be easily modified to work with
# your specific directory structure and filenames conventions (BIDS, etc).

echo """
The script is designed to work with the following directory structure:
input/
├── subject1/
│   ├── *t1.nii.gz
│   ├── *t2.nii.gz
│   ├── *dwi.nii.gz
│   ├── *dwi.bval
│   ├── *dwi.bvec
│   ├── *revb0.nii.gz
│   ├── *labels.nii.gz
│   ├── *wmparc.nii.gz
│   ├── *.trk
│   ├── *peaks.nii.gz
│   ├── *fodf.nii.gz
│   ├── *mat.txt
│   ├── *warp.nii.gz
│   ├── metrics/
│       └── *.nii.gz
├── subject2/
│   └── ...
└── subject3/
    └── ...

The script will loop through the input directory and assemble a samplesheet with the following columns:
subject,t1,t2,dwi,bval,bvec,rev_b0,labels,wmparc,trk,peaks,fodf,mat,warp,metrics

The script can be executed as follows:
bash assemble_samplesheet.sh input output.csv
"""

# Define the input dir.
input=$1

# Define the output file.
output=$2

# Define the header. (DO NOT CHANGE)
header="subject,t1,t2,dwi,bval,bvec,rev_b0,labels,wmparc,trk,peaks,fodf,mat,warp,metrics"
echo $header > $output

# Loop through the input directory and assemble the samplesheet.
for dir in $input/*; do
    if [ -d $dir ]; then

        # Fetch sample name.
        subject=$(basename $dir)

        # Fetch the required files.
        if [ -f $dir/*t1.nii.gz ]; then
            t1=$(realpath $dir/*t1.nii.gz)
        else
            t1=""
        fi

        if [ -f $dir/*t2.nii.gz ]; then
            t2=$(realpath $dir/*t2.nii.gz)
        else
            t2=""
        fi

        if [ -f $dir/*dwi.nii.gz ]; then
            dwi=$(realpath $dir/*dwi.nii.gz)
        else
            dwi=""
        fi

        if [ -f $dir/*dwi.bval ]; then
            bval=$(realpath $dir/*dwi.bval)
        else
            bval=""
        fi

        if [ -f $dir/*dwi.bvec ]; then
            bvec=$(realpath $dir/*dwi.bvec)
        else
            bvec=""
        fi

        if [ -f $dir/*revb0.nii.gz ]; then
            rev_b0=$(realpath $dir/*revb0.nii.gz)
        else
            rev_b0=""
        fi

        if [ -f $dir/*labels.nii.gz ]; then
            labels=$(realpath $dir/*labels.nii.gz)
        else
            labels=""
        fi

        if [ -f $dir/*wmparc.nii.gz ]; then
            wmparc=$(realpath $dir/*wmparc.nii.gz)
        else
            wmparc=""
        fi

        if [ -f $dir/*.trk ]; then
            trk=$(realpath $dir/*.trk)
        else
            trk=""
        fi

        if [ -f $dir/*peaks.nii.gz ]; then
            peaks=$(realpath $dir/*peaks.nii.gz)
        else
            peaks=""
        fi

        if [ -f $dir/*fodf.nii.gz ]; then
            fodf=$(realpath $dir/*fodf.nii.gz)
        else
            fodf=""
        fi

        if [ -f $dir/*mat.txt ]; then
            mat=$(realpath $dir/*mat.txt)
        else
            mat=""
        fi

        if [ -f $dir/*warp.nii.gz ]; then
            warp=$(realpath $dir/*warp.nii.gz)
        else
            warp=""
        fi

        if [ -d $dir/metrics ]; then
            metrics=$(realpath $dir/metrics)
        else
            metrics=""
        fi

        # Write the assembled samplesheet.
        echo "$subject,$t1,$t2,$dwi,$bval,$bvec,$rev_b0,$labels,$wmparc,$trk,$peaks,$fodf,$mat,$warp,$metrics" >> $output
    fi
done

echo "Samplesheet assembled successfully!"
