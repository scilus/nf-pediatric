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


for types in ["mean_stats", "point_stats"]:
    files = glob.glob(f"*{types}*")
    df = pd.concat([pd.read_csv(f, sep="\t") for f in files], ignore_index=True)
    df.to_csv(f"bundles_{types}.tsv", sep="\t", index=False)

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "pandas": pd.__version__,
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
