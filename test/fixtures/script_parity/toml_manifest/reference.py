#!/usr/bin/env python3
"""Independent bounded reference for the A06/C07 Cargo TOML parity slice."""

import sys
import tomllib


def render(path):
    with open(path, "rb") as source:
        manifest = tomllib.load(source)

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


def main(arguments):
    if len(arguments) != 2 or arguments[0] != "--parity-batch":
        return 2
    sys.stdout.write(render(arguments[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
