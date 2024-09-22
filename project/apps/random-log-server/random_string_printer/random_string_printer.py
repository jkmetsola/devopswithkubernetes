#!/usr/bin/env python3

"""Generates and prints random strings."""

import argparse
import json
import secrets
import string
import time
from datetime import datetime, timezone
from pathlib import Path


class RandomStringPrinter:
    """Generate and print random strings."""

    @staticmethod
    def _generate_random_string(length: int = 12) -> str:
        letters = string.ascii_letters + string.digits
        return "".join(secrets.choice(letters) for _ in range(length))

    @staticmethod
    def run(logfile: str, pongfile: str) -> None:
        """Print a random string every 5 seconds."""
        while True:
            with Path(pongfile).open() as f:
                pongs = json.load(f)["counter"]
            random_string = (
                RandomStringPrinter._generate_random_string() + "\n"
                "Pings / Pongs: " + str(pongs)
            )
            timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
            with Path(logfile).open("w") as f:
                f.write(f"{timestamp} - {random_string}\n")
            time.sleep(5)

    @staticmethod
    def parse_args() -> argparse.ArgumentParser:
        """Set up command-line argument parser."""
        parser = argparse.ArgumentParser(description="Simple Log Server")
        parser.add_argument(
            "--logfile", type=str, required=True, help="Path to the log file to serve"
        )
        parser.add_argument(
            "--pongfile", type=str, required=True, help="Path to the pong file"
        )
        return parser.parse_args()


if __name__ == "__main__":
    args = RandomStringPrinter.parse_args()
    RandomStringPrinter.run(logfile=args.logfile, pongfile=args.pongfile)