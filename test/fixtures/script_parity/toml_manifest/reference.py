#!/usr/bin/env python3
"""Independent reference for the observed Cargo and Python project TOML slices."""

import sys
import tomllib


def load(path):
    with open(path, "rb") as source:
        return tomllib.load(source)


def render_cargo(path):
    manifest = load(path)
    workspace = manifest["workspace"]
    dependencies = workspace["dependencies"]
    wasmtime = dependencies["wasmtime"]
    sha2_alias = dependencies["sha2_11"]
    rows = [
        f"workspace.resolver={workspace['resolver']}",
        f"workspace.package.version={workspace['package']['version']}",
        f"workspace.package.edition={workspace['package']['edition']}",
    ]
    rows.extend(f"workspace.member={member}" for member in workspace["members"])
    rows.extend(
        [
            f"workspace.dependencies.wasmtime.version={wasmtime['version']}",
            f"workspace.dependencies.wasmtime.feature={wasmtime['features'][0]}",
            f"workspace.dependencies.sha2_11.package={sha2_alias['package']}",
            f"workspace.dependencies.sha2_11.version={sha2_alias['version']}",
        ]
    )
    return "\n".join(rows) + "\n"


def render_pyproject(path):
    project = load(path)
    rows = [
        f"pyproject.project.name={project['project']['name']}",
        f"pyproject.project.version={project['project']['version']}",
        f"pyproject.project.requires-python={project['project']['requires-python']}",
        f"pyproject.build-system.build-backend={project['build-system']['build-backend']}",
    ]
    rows.extend(
        f"pyproject.build-system.requires={requirement}"
        for requirement in project["build-system"]["requires"]
    )
    rows.append(f"pyproject.tool.ruff.target-version={project['tool']['ruff']['target-version']}")
    rows.extend(
        f"pyproject.tool.ruff.extend-exclude={entry}"
        for entry in project["tool"]["ruff"]["extend-exclude"]
    )
    rows.extend(
        f"pyproject.tool.setuptools.packages.find.where={entry}"
        for entry in project["tool"]["setuptools"]["packages"]["find"]["where"]
    )
    pytest = project["tool"]["pytest"]["ini_options"]
    rows.extend(f"pyproject.tool.pytest.pythonpath={entry}" for entry in pytest["pythonpath"])
    rows.extend(f"pyproject.tool.pytest.testpaths={entry}" for entry in pytest["testpaths"])
    rows.extend(f"pyproject.tool.pytest.python_files={entry}" for entry in pytest["python_files"])
    rows.append(f"pyproject.tool.pytest.addopts={pytest['addopts']}")
    rows.extend(f"pyproject.tool.pytest.marker={entry}" for entry in pytest["markers"])
    return "\n".join(rows) + "\n"


def main(arguments):
    if len(arguments) != 3 or arguments[0] != "--parity-batch":
        return 2
    sys.stdout.write(render_cargo(arguments[1]) + render_pyproject(arguments[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
