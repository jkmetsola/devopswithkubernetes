#!/usr/bin/env python3
"""A tool to execute tests using configurations in .vscode/launch.json."""

import argparse
import json
import shlex
import subprocess
from pathlib import Path

with Path.open(".vscode/launch.json") as f:
    launch_config = json.load(f)
config_names = [config["name"] for config in launch_config["configurations"]]

parser = argparse.ArgumentParser(description="CLI for executing tests.")
parser.add_argument(
    "test_launcher_config",
    choices=config_names,
    help="choose one of %(choices)s",
)
args = parser.parse_args()


def obtain_config() -> dict:
    """Obtain the configuration."""
    return next(
        config
        for config in launch_config["configurations"]
        if config["name"] == args.test_launcher_config
    )


command = f"{obtain_config()['module']} {' '.join(obtain_config()['args'])}"
command = shlex.split(command)
result = subprocess.run(command, check=True, shell=True)  # noqa: S602
