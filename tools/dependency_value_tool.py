#!/usr/bin/env python3
"""Resolving dependency values from values.yaml files in a Kubernetes environment."""

from __future__ import annotations

import sys
from pathlib import Path
from traceback import format_exception
from typing import TYPE_CHECKING, Generator  # noqa: UP035

if TYPE_CHECKING:
    import types

import argparse
from argparse import Namespace

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
        if var == "self":
            for attr in dir(val):
                if not attr.startswith("__"):
                    try:
                        value = getattr(val, attr)
                        sys.stderr.write(f"{attr} = {value}\n")
                    except Exception:  # noqa: BLE001, S110
                        pass
        else:
            sys.stderr.write(f"{var} = {val}\n")
    traceback_txt = "".join(format_exception(exc_type, exc_value, exc_traceback))
    sys.stderr.write(traceback_txt)
    sys.exit(1)


sys.excepthook = exception_hook


class DependencyResolver:  # noqa: D101
    def __init__(  # noqa: D107
        self, values_yaml: str, global_values_yaml: str, resolved_values_yaml: str
    ) -> None:
        self.app_path = Path(values_yaml) / ".." / ".."
        self.resolved_values_yaml = resolved_values_yaml
        self.dep_value_map = {}
        with Path(values_yaml).open() as f:
            self.values_yaml = yaml.safe_load(f)
        with Path(global_values_yaml).open() as f:
            self.global_values_yaml = yaml.safe_load(f)

    def dep_map_generator(
        self,
        project: str,
        value_map: dict,
    ) -> Generator[tuple[str, str, str, str]]:
        """Generate a map of dependencies from the values.yaml file."""
        for app_type, apps in value_map.items():
            for app, keys in apps.items():
                for key in keys:
                    yield (
                        self._get_dep_value(project, app_type, app, key),
                        app_type,
                        app,
                        key,
                    )

    def _get_dep_value(self, project: str, app_type: str, app: str, key: str) -> Path:
        _path = (
            Path(f"{self.app_path}/../../../{project}/{app_type}/{app}")
            / VALUES_YAML_RELATIVE_PATH
        )
        with _path.resolve().open() as f:
            return yaml.safe_load(f)[key]

    def _resolve_dep_values_map(self, project: str, dep_values: dict) -> None:
        for dep_value, app_type, app, key in self.dep_map_generator(
            project, dep_values
        ):
            self.dep_value_map[app_type] = self.dep_value_map.get(app_type, {})
            self.dep_value_map[app_type][app] = self.dep_value_map[app_type].get(
                app, {}
            )
            self.dep_value_map[app_type][app][key] = dep_value

            if self.values_yaml.get(app_type, {}).get(app, {}).get(key):
                msg = f"Same key defined in the values.yaml! {app_type}.{app}.{key}"
                raise AssertionError(msg)

    def _resolve_dep_values_map_no_route(self, project: str, dep_values: dict) -> None:
        for dep_value, _, _, key in self.dep_map_generator(project, dep_values):
            self._check_key_not_in_map(key)
            self.dep_value_map[key] = dep_value
            self._check_key_not_in_values_yaml(key)

    def _check_key_not_in_map(self, key: str) -> None:
        if self.dep_value_map.get(key):
            msg = f"Same key defined already in depepndency value map! {key}"
            raise AssertionError(msg)

    def _check_key_not_in_values_yaml(self, key: str) -> None:
        if self.values_yaml.get(key):
            msg = f"Same key defined in the values.yaml! {key}"
            raise AssertionError(msg)

    def _access_all_the_keys(self, proj: str, deps: dict) -> None:
        for _, app_type, app, key in self.dep_map_generator(proj, deps):
            self.dep_value_map[app_type][app][key]

    def main(self) -> None:  # noqa: D102
        for proj, deps in self.values_yaml.get("depValues", {}).items():
            self._resolve_dep_values_map(proj, deps)
            self._access_all_the_keys(proj, deps)
        for proj, deps in self.values_yaml.get("depValuesNoRoute", {}).items():
            self._resolve_dep_values_map_no_route(proj, deps)
        self.dep_value_map.update(self.global_values_yaml)
        with Path(self.resolved_values_yaml).open("w") as f:
            yaml.safe_dump(dict(self.dep_value_map), f)

    @staticmethod
    def parse_args() -> Namespace:  # noqa: D102
        parser = argparse.ArgumentParser(
            description="Resolve dependency values from values.yaml files."
        )
        parser.add_argument(
            "--values-yaml",
            help="Path to the values.yaml which dependencies are resolved",
        )
        parser.add_argument(
            "--global-values-yaml", help="Path to the global values.yaml file"
        )
        parser.add_argument(
            "--resolved-values-yaml",
            help="Path to the destination file where resolved values will be saved",
        )
        return parser.parse_args()


if __name__ == "__main__":
    args = DependencyResolver.parse_args()
    DependencyResolver(
        values_yaml=args.values_yaml,
        global_values_yaml=args.global_values_yaml,
        resolved_values_yaml=args.resolved_values_yaml,
    ).main()
