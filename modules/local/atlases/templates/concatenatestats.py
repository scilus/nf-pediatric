#!/usr/bin/env python3

import glob
import platform

import pandas as pd


def format_yaml_like(data: dict, indent: int = 0) -> str:
    """Formats a dictionary to a YAML-like string.
    Pulled from the scvitools/solo nf-core modules.
    https://github.com/nf-core/modules/nf-core/scvitools/solo/templates/solo.py

    Args:
        data (dict): The dictionary to format.
        indent (int): The current indentation level.

    Returns:
        str: A string formatted as YAML.
    """
    yaml_str = ""
    for key, value in data.items():
        spaces = "    " * indent
        if isinstance(value, dict):
            yaml_str += f"{spaces}{key}:\\n{format_yaml_like(value, indent + 1)}"
        else:
            yaml_str += f"{spaces}{key}: {value}\\n"
    return yaml_str


for stat in ['volume', 'area', 'thickness', 'subcortical']:
    if stat == 'subcortical':
        files = glob.glob("*subcortical*")
        df = pd.concat([pd.read_csv(f, sep='\\t') for f in files], ignore_index=True)
        df.rename(columns={df.columns[0]: "Sample"}, inplace=True)
        df.to_csv(f"{stat}_volumes.tsv", sep='\\t', index=False)
    else:
        for hemi in ['lh', 'rh']:
            files = glob.glob(f"*{stat}_{hemi}*")
            df = pd.concat([pd.read_csv(f, sep='\\t') for f in files], ignore_index=True)
            df.rename(columns={df.columns[0]: "Sample"}, inplace=True)
            if stat == "thickness":
                # Specific to the Brainnetome atlas, drop some columns if they exist.
                if "BrainSegVolNotVent" in df.columns:
                    df.drop(columns=["BrainSegVolNotVent", "eTIV", f"{hemi}_cluster94_{stat}",
                                    f"{hemi}_MeanThickness_{stat}"], inplace=True)
            elif stat == "area":
                # Specific to the Brainnetome atlas, drop some columns if they exist.
                if "BrainSegVolNotVent" in df.columns:
                    df.drop(columns=["BrainSegVolNotVent", "eTIV", f"{hemi}_cluster94_{stat}",
                                    f"{hemi}_WhiteSurfArea_{stat}"], inplace=True)
            else:
                # Specific to the Brainnetome atlas, drop some columns if they exist.
                if "BrainSegVolNotVent" in df.columns:
                    df.drop(columns=["BrainSegVolNotVent", "eTIV", f"{hemi}_cluster94_{stat}"], inplace=True)
            df.columns = [col.replace(f"_{stat}", "") for col in df.columns]
            df.to_csv(f"cortical_{stat}_{hemi}.tsv", sep='\\t', index=False)

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "pandas": pd.__version__,
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
