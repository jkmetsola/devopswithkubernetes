#!/usr/bin/env python3
"""Simple script to update the devcontainer.json file."""

import argparse
import json
import logging
import sys
from copy import deepcopy
from pathlib import Path

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


class ConfiguredevEnv:
    """Tool to update the devcontainer.json file."""

    def __init__(self) -> None:
        """Get data from devcontainer.json file."""
        self.devcontainer_json_path = Path.joinpath(
            Path(__file__).parent,
            "devcontainer.json",
        )
        with self.devcontainer_json_path.open(encoding="utf-8") as file:
            self.devcontainer_json_data = json.load(file)
        self.devcontainer_json_data_copy = deepcopy(self.devcontainer_json_data)
        self.build_arguments = [
            f"{key}={value}"
            for key, value in self.devcontainer_json_data["build"]["args"].items()
        ]

    @staticmethod
    def parse_args() -> argparse.Namespace:
        """Parse args from the command line."""
        parser = argparse.ArgumentParser(
            description="Update the devcontainer.json file.",
        )

        parser.add_argument("--host-docker-gid", type=int, help="Host Docker Group ID")
        parser.add_argument("--host-uid", type=int, help="Host User ID")
        parser.add_argument("--host-gid", type=int, help="Host Group ID")
        parser.add_argument("--build-arg-output-file", type=str)
        parser.add_argument("--build-env-output-file", type=str)
        parser.add_argument(
            "--modify-devcontainer-json",
            type=str,
            choices=["true", "false"],
        )

        return parser.parse_args()

    def configure_dev_env(
        self,
        host_docker_gid: str,
        host_uid: str,
        host_gid: str,
    ) -> None:
        """Update the devcontainer.json file."""
        self.devcontainer_json_data["build"]["args"]["HOST_DOCKER_GID"] = (
            host_docker_gid
        )
        self.devcontainer_json_data["build"]["args"]["HOST_UID"] = host_uid
        self.devcontainer_json_data["build"]["args"]["HOST_GID"] = host_gid

        with Path.open(self.devcontainer_json_path, "w", encoding="utf-8") as file:
            json.dump(self.devcontainer_json_data, file, indent=4)

        if self.devcontainer_json_data != self.devcontainer_json_data_copy:
            logger.warning(
                ".devcontainer/devcontainer.json updated. Restart the container.",
            )
            sys.exit(1)

    def create_buildargs_file(self, build_arg_output_file: str) -> None:
        """Create the buildargs file."""
        with Path(build_arg_output_file).open("w", encoding="utf-8") as file:
            file.write("--build-arg" + " " + " --build-arg ".join(self.build_arguments))

    def create_buildenv_file(self, build_env_output_file: str) -> None:
        """Create the 'build-environment' file."""
        with Path(build_env_output_file).open("w", encoding="utf-8") as file:
            file.write("\n".join(self.build_arguments))


if __name__ == "__main__":
    args = ConfiguredevEnv.parse_args()
    envconfigurer = ConfiguredevEnv()
    if args.modify_devcontainer_json == "true":
        envconfigurer.configure_dev_env(
            args.host_docker_gid,
            args.host_uid,
            args.host_gid,
        )
    envconfigurer.create_buildargs_file(args.build_arg_output_file)
    envconfigurer.create_buildenv_file(args.build_env_output_file)
