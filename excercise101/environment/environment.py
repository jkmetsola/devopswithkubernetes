"""Server configuration from environment variables."""

import argparse
import os
import sys


class EnvironmentInit:
    """Server configuration from command line variables."""

    def __init__(self) -> None:
        """Set environment variables from command line arguments."""
        parser = argparse.ArgumentParser(
            description="Set environment variables for server configuration."
        )
        parser.add_argument("--logfile", required=True, help="Path to the log file")
        parser.add_argument(
            "--port", required=True, type=int, help="Port to run the server on"
        )
        args = parser.parse_args()
        os.environ["LOG_FILE"] = args.logfile
        os.environ["PORT"] = str(args.port)
        sys.stdout.write("Following environment variables set:\n")
        sys.stdout.write(f"LOG_FILE={os.environ['LOG_FILE']}\n")
        sys.stdout.write(f"PORT={os.environ['PORT']}\n")
        sys.stdout.flush()


class Environment:
    """Class to retrieve server configuration from environment variables."""

    @property
    def log_file(self) -> str:
        """Retrieve the log file path from environment variables."""
        return os.environ["LOG_FILE"]

    @property
    def port(self) -> int:
        """Retrieve the port number from environment variables."""
        return int(os.environ["PORT"])
