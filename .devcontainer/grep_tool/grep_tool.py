#!/usr/bin/env python3
"""Tool for grepping through git-tracked files."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from typing import Generator  # noqa: UP035

from logger import logger
from whitelist_parser import WhiteListFileParser


class CommandLineTool:  # noqa: D101
    bash = shutil.which("bash")

    def _cmd_prefix(self) -> str:
        """Get the command prefix."""
        return [self.bash, "-c"]

    def _exec_cmd_output(self, sub_cmd: str) -> list:
        cmd = [*self._cmd_prefix(), sub_cmd]
        process = subprocess.Popen([*cmd], stdout=subprocess.PIPE)  # noqa: S603
        stdout, _ = process.communicate()
        if stdout.decode() != "":
            output = stdout.decode().strip("\n").split("\n")
            logger.debug("Command: %s", " ".join(cmd))
            logger.debug("Output: %s", output)
            return output
        return []


class GitFilesCommandLineTool(CommandLineTool):  # noqa: D101
    git = shutil.which("git")

    def _git_added_files(self) -> list:
        return self._exec_cmd_output(self._git_diff_index_cmd("A"))

    def _git_renamed_files(self) -> list:
        return self._exec_cmd_output(self._git_diff_index_cmd("R"))

    def _git_modified_files(self) -> list:
        return self._exec_cmd_output(self._git_diff_index_cmd("M"))

    def _git_files(self) -> list:
        deleted_files = self._exec_cmd_output(f"{self.git} ls-files -d")
        return [
            file
            for file in self._exec_cmd_output(f"{self.git} ls-files")
            if file not in deleted_files
        ]

    def _git_diff_index_cmd(self, filter_letter: str) -> str:
        """Get the git diff-index command."""
        return " ".join(
            [
                self.git,
                "diff-index",
                "--cached",
                "--name-status",
                f"--diff-filter {filter_letter}",
                "-M",
                "HEAD",
                "|",
                "awk",
                "'{print $2}'",
            ]
        )


class GitFilesGrepTool(GitFilesCommandLineTool):
    """A tool for grepping through git-tracked files."""

    grep = shutil.which("grep")

    def __init__(self, whitelist_file: str, previous_commit_sha: str) -> None:  # noqa: D107
        self.whitelist_file = whitelist_file
        self.previous_commit_sha = previous_commit_sha
        self.whitelist_parser = WhiteListFileParser(
            self.whitelist_file, self.previous_commit_sha
        )

    def _files_after_whitelist(self, files: list) -> Generator[str]:
        return (
            file for file in files if not self.whitelist_parser.is_whitelisted(file)
        )

    def _create_whitelisted_grep_command(self, cmd: str) -> str:
        return f"{cmd} | {self.grep} -Ev '^[ ]*#'"

    def _file_matches_gen(
        self, changed_files: list
    ) -> Generator[tuple[int, str, list, list, list, str]]:
        for i, changed_file in enumerate(self._files_after_whitelist(changed_files)):
            for file in self._files_after_whitelist(self._git_files()):
                yield (
                    i,
                    changed_file,
                    self._exec_cmd_output(f"{self.grep} -Fcw {changed_file} {file}"),
                    self._exec_cmd_output(
                        grep_cmd := self._create_whitelisted_grep_command(
                            f"{self.grep} --color=always -Fw {changed_file} {file}"
                        )
                    ),
                    self._exec_cmd_output(
                        f"{self.grep} --color=always -HnFw {changed_file} {file}"
                    ),
                    self._exec_cmd_output(
                        f"{self.git} status | {self.grep} --color=always "
                        f"-w {changed_file}",
                    ),
                    grep_cmd,
                )

    def _process_matches(
        self,
        matches_gen: Generator,
        desired_matches: int,
    ) -> Generator[tuple[str, int, bool, list]]:
        matches = 0
        current_index = 0
        outputs = []
        current_changed_file = None
        for (
            i,
            changed_file,
            count,
            output,
            output_detailed,
            status,
            grep_cmd,
        ) in matches_gen:
            if current_index != i:
                verdict = matches == desired_matches
                yield (current_changed_file, matches, verdict, outputs)
                matches = 0
                outputs = []
                current_index = i
            current_changed_file = changed_file

            if int(count[0]) > 0 and output != []:
                matches += int(count[0])
                outputs.append(
                    {"command": grep_cmd, "output": output_detailed + status}
                )

    def main(self) -> None:  # noqa: D102
        generators_map = {
            "renamed": self._file_matches_gen(self._git_renamed_files()),
            "added": self._file_matches_gen(self._git_added_files()),
            "modified": self._file_matches_gen(self._git_modified_files()),
        }
        desired_matches_map = {
            "renamed": 0,
            "added": 1,
            "modified": 1,
        }
        verdicts = []
        for key in generators_map:  # noqa: PLC0206
            for changed_file, matches, verdict, output in self._process_matches(
                generators_map[key],
                desired_matches_map[key],
            ):
                verdicts.append(
                    {
                        "fileName": changed_file,
                        "verdict": verdict,
                        "matchesAmountDesired": desired_matches_map[key],
                        "matchesAmount": matches,
                        "fileModificationType": key,
                    }
                )
                if not verdict:
                    for _out in output:
                        sys.stderr.write(f"Command: {_out['command']} \n\n")
                        sys.stderr.write("\n".join(_out["output"]) + "\n\n")
                        sys.stderr.flush()

        failed_files = [
            result for i, result in enumerate(verdicts) if not verdicts[i]["verdict"]
        ]
        if failed_files:
            err_msg = "Undesired amount of matches found " + json.dumps(
                failed_files, indent=4
            )
            raise AssertionError(err_msg)

    @staticmethod
    def parse_args() -> argparse.Namespace:
        """Parse args from the command line."""
        parser = argparse.ArgumentParser(description=GitFilesGrepTool.__doc__)
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
        return parser.parse_args()


if __name__ == "__main__":
    args = GitFilesGrepTool.parse_args()
    GitFilesGrepTool(args.whitelist_file, args.previous_commit_sha).main()
