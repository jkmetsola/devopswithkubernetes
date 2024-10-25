#!/usr/bin/env python3
"""A Tool for sorting applications based on order files."""

import os
import re
import sys
from pathlib import Path


class AppSorter:  # noqa: D101
    def __init__(self, search_dir: str) -> None:  # noqa: D107
        self.search_dir = search_dir

    def sorted_apps(self) -> list:  # noqa: D102
        order_files = list(self._find_order_files())
        directories = list(self._find_dirs())
        if len(order_files) != len(directories):
            err_msg = (
                "The number of order files does not match the number of directories.\n"
                f"Directories: {directories}\n"
                f"Order Files: {order_files}\n"
            )
            raise AssertionError(err_msg)
        order_files.sort(key=lambda x: x[1])
        return [Path(root).name for root, _ in order_files]

    def write_sorted_apps(self, output_file: str) -> None:  # noqa: D102
        with Path(output_file).open("w") as f:
            f.writelines(f"{app}\n" for app in self.sorted_apps())

    def _find_order_files(self) -> iter:
        for root, _, files in os.walk(self.search_dir, followlinks=True):
            yield from (
                (root, file) for file in files if re.match(r"^[0-9][0-9]\.order", file)
            )

    def _find_dirs(self) -> iter:
        for i, (_, dirs, _) in enumerate(os.walk(self.search_dir, followlinks=True)):
            if i == 1:
                break
            yield from dirs


if __name__ == "__main__":
    AppSorter(sys.argv[1]).write_sorted_apps(sys.argv[2])
