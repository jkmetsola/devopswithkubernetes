#!/usr/bin/env python3

"""WhiteListFileParser tool."""

import json
import re
import sys
from pathlib import Path

from logger import logger


class WhiteListFileParser:
    """A tool to parse the whitelist file."""

    def __init__(self, whitelistfile: str, previous_commit_sha: str) -> None:
        """Read the whitelist file and validate it."""
        with Path(whitelistfile).open("r", encoding="utf-8") as file:
            self.data = json.load(file)
            self.whitelisted_files = (
                self.data.get(previous_commit_sha, []) + self.data["permanent"]
            )
            self.whitelisted_patterns = self.data.get("patterns", [])
        self.validate_whitelist_file()

    def is_whitelisted(self, file: str) -> bool:
        """Check if a file is whitelisted."""
        return file in self.whitelisted_files or any(
            re.search(pattern, file) for pattern in self.whitelisted_patterns
        )

    def validate_whitelist_file(self) -> None:
        """Validate the whitelist file."""
        if not all(
            key in ["permanent", "patterns"] or re.search("^[0-9a-f]{40}$", key)
            for key in self.data
        ):
            logger.error("Invalid keys in whitelist file")
            sys.exit(1)
