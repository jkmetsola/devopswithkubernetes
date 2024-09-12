#!/usr/bin/env python3

"""Generates and prints random strings."""

import secrets
import string
import time
from datetime import datetime, timezone
from pathlib import Path

from environment.environment import Environment


class RandomStringPrinter:
    """Generate and print random strings."""

    @staticmethod
    def _generate_random_string(length: int = 12) -> str:
        letters = string.ascii_letters + string.digits
        return "".join(secrets.choice(letters) for _ in range(length))

    @staticmethod
    def run() -> None:
        """Print a random string every 5 seconds."""
        while True:
            random_string = RandomStringPrinter._generate_random_string()
            timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
            with Path(Environment().log_file).open("w") as f:
                f.write(f"{timestamp} - {random_string}\n")
            time.sleep(5)
