#!/usr/bin/env python3

"""Generates and prints random strings."""

import secrets
import string
import sys
import time
from datetime import datetime, timezone


def generate_random_string(length: int = 12) -> str:  # noqa: D103
    letters = string.ascii_letters + string.digits
    return "".join(secrets.choice(letters) for _ in range(length))


def main() -> None:
    """Print a random string every 5 seconds."""
    random_string = generate_random_string()
    while True:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        sys.stdout.write(f"{timestamp} - {random_string}\n")
        sys.stdout.flush()
        time.sleep(5)


if __name__ == "__main__":
    main()
