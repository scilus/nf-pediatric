#!/bin/python

import argparse
import logging

import pandas as pd

def _build_arg_parser():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawTextHelpFormatter)

    p.add_argument('-i', '--input', required=True,
                   help='Input freesurfer stats file (.stats)')
    p.add_argument('-o', '--output', required=True,
                     help='Output tsv file')

    p.add_argument('-m', '--measure', required=True,
                   help='Measure to extract from stats file',
                   choices=['GrayVol', 'SurfArea', 'ThickAvg'])
    p.add_argument('-s', '--subject', required=True,
                   help='Subject ID')

    return p


def main():
    parser = _build_arg_parser()
    args = parser.parse_args()
    logging.getLogger().setLevel(logging.INFO)

    # Load stats file.
    df = pd.read_csv(args.input)

    # Freesurfer stats file have regions as rows and measures as columns,
    # need to transpose it with the desired measure.
    df_m = df.loc[:, ["StructName", args.measure]].T

    # Setting the first row as the column names.
    df_m.columns = df_m.iloc[0]

    # Dropping the first row.
    df_m = df_m[1:]

    # Replace first column name with "Sample" and add subject ID.
    df_m.columns.name = "Sample"
    df_m.index = [args.subject]

    # Dropping the medial wall column.
    df_m = df_m.drop(columns="Medial_Wall")

    # Save to tsv.
    df_m.to_csv(args.output, sep='\t', index=True, header=True)


if __name__ == '__main__':
    main()
