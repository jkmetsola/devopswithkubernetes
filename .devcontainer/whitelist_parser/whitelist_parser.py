#!/usr/bin/env python3

"""Module that can be used as an interface to WhiteListFileParser tool.

Two usage options:
1. Import WhiteListFileParser tool from this file.
2. Call this file to use WhiteListFileParser tool from CLI.

"""

import argparse
import json
import logging
import sys
from pathlib import Path

# Configure the logger
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class WhiteListFileParser:
    """A tool to parse the whitelist file and output contents to a temporary text file.

    Temporary text file will be in a format that can be parsed by bash scripts.
    """

    def __init__(self, whitelistfile: str, previous_commit_sha: str) -> None:
        """Read the whitelist file and validate it."""
        with Path(whitelistfile).open("r", encoding="utf-8") as file:
            self.data = json.load(file)
            self.whitelisted_files = (
                self.data.get(previous_commit_sha, []) + self.data["permanent"]
            )
        self.validate_whitelist_file()

    def exit_if_file_is_whitelisted(self, file: str) -> None:
        """Exit 1 if a file is not whitelisted."""
        if file not in self.whitelisted_files:
            logger.debug("File %s is not whitelisted.", file)
            sys.exit(1)

    def validate_whitelist_file(self) -> None:
        """Validate the whitelist file."""
        if len(self.data.keys()) > 2:  # noqa: PLR2004
            logger.error("Whitelist file has more than two keys")
            sys.exit(1)
        if "permanent" not in self.data:
            logger.error("'permanent' key not found in whitelist file")
            sys.exit(1)

    @staticmethod
    def parse_args() -> argparse.Namespace:
        """Parse args from the command line."""
        parser = argparse.ArgumentParser(description=WhiteListFileParser.__doc__)
        parser.add_argument(
            "--whitelist-file",
            type=str,
            help="Path to the whitelist file",
        )
        parser.add_argument(
            "--previous-commit-sha",
            type=str,
            help="Previous commit SHA",
        )
        parser.add_argument(
            "--file",
            type=str,
            help="File to check if whitelisted",
        )
        return parser.parse_args()


if __name__ == "__main__":
    args = WhiteListFileParser.parse_args()
    WhiteListFileParser(
        args.whitelist_file,
        args.previous_commit_sha,
    ).exit_if_file_is_whitelisted(args.file)
