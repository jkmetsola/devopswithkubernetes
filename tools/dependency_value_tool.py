#!/usr/bin/env python3
"""Resolving dependency values from values.yaml files in a Kubernetes environment."""

from __future__ import annotations

import sys
from pathlib import Path
from traceback import format_exception
from typing import TYPE_CHECKING, Generator

if TYPE_CHECKING:
    import types

import yaml

VALUES_YAML_RELATIVE_PATH = "manifests/values.yaml"


def exception_hook(
    exc_type: type[BaseException],
    exc_value: BaseException,
    exc_traceback: types.TracebackType,
) -> None:
    """Handle uncaught exceptions and print them to stderr."""
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return
    tb = exc_traceback
    while tb.tb_next:
        tb = tb.tb_next
    frame = tb.tb_frame
    for var, val in frame.f_locals.items():
        sys.stderr.write(f"{var} = {val}\n")
    traceback_txt = "".join(format_exception(exc_type, exc_value, exc_traceback))
    sys.stderr.write(traceback_txt)
    sys.exit(1)


sys.excepthook = exception_hook


class DependencyResolver:  # noqa: D101
    def __init__(self, app_path: str, global_values_yaml: str, dest_file: str) -> None:  # noqa: D107
        self.app_path = app_path
        self.dest_file = dest_file
        self.dep_value_map = {}
        with Path(f"{app_path}/{VALUES_YAML_RELATIVE_PATH}").open() as f:
            self.values_yaml = yaml.safe_load(f)
        with Path(global_values_yaml).open() as f:
            self.global_values_yaml = yaml.safe_load(f)
        self.dependency_values = self.values_yaml.get("dependencyValues")

    def dep_map_generator(self) -> Generator[tuple[str, str, str]]:
        """Generate a map of dependencies from the values.yaml file."""
        for app_type, apps in self.dependency_values.items():
            for app, keys in apps.items():
                for key in keys:
                    yield app_type, app, key

    def dep_app_values_yaml(self, app_type: str, app: str) -> Path:
        """Return the path to the values.yaml file for a given app type and app."""
        return Path(
            f"{self.app_path}/../../{app_type}/{app}/{VALUES_YAML_RELATIVE_PATH}"
        )

    def extract_dependency_values(self) -> None:
        """Extract dependency values from the values.yaml files."""
        for app_type, app, key in self.dep_map_generator():
            with self.dep_app_values_yaml(app_type, app).open() as f:
                dep_value = yaml.safe_load(f)[key]

            if self.dep_value_map.get(app_type, {}).get(app):
                self.dep_value_map[app_type][app].update({key: dep_value})
            else:
                self.dep_value_map.update(
                    {
                        app_type: {
                            app: {key: dep_value},
                        }
                    }
                )
            if self.values_yaml.get(app_type, {}).get(app, {}).get(key):
                msg = f"Same key defined in the values.yaml! {app_type}.{app}.{key}"
                raise AssertionError(msg)

    def access_all_the_keys(self) -> None:
        """Access all the keys in the generated resolved map to verify."""
        for app_type, app, key in self.dep_map_generator():
            self.dep_value_map[app_type][app][key]

    def create_resolved_dep_value_map(self) -> None:  # noqa: D102
        if self.dependency_values:
            self.extract_dependency_values()
            self.access_all_the_keys()
        self.dep_value_map.update(self.global_values_yaml)
        with Path(self.dest_file).open("w") as f:
            yaml.safe_dump(dict(self.dep_value_map), f)


if __name__ == "__main__":
    DependencyResolver(
        sys.argv[1], sys.argv[2], sys.argv[3]
    ).create_resolved_dep_value_map()
