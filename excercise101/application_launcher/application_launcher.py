#!/usr/bin/env python3
"""Launches the random string printer and simple log server applications."""

import multiprocessing as mp

from environment.environment import EnvironmentInit
from random_string_printer.random_string_printer import RandomStringPrinter
from simple_log_server.simple_log_server import LogServer


class ApplicationLauncher:
    """Launches the random string printer and simple log server applications."""

    @staticmethod
    def main() -> None:
        """Launch the random string printer and log server applications."""
        p1 = mp.Process(target=RandomStringPrinter.run)
        p2 = mp.Process(target=LogServer.run)
        p1.start()
        p2.start()
        p1.join()
        p2.join()


if __name__ == "__main__":
    EnvironmentInit()
    ApplicationLauncher.main()
