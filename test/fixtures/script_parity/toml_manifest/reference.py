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


def render_hugo(path):
    config = load(path)
    rows = [
        f"hugo.baseURL={config['baseURL']}",
        f"hugo.title={config['title']}",
        f"hugo.enableRobotsTXT={str(config['enableRobotsTXT']).lower()}",
    ]
    rows.extend(f"hugo.theme={entry}" for entry in config["theme"])
    rows.extend(f"hugo.disableKinds={entry}" for entry in config["disableKinds"])
    rows.extend(
        [
            f"hugo.permalinks.blog={config['permalinks']['blog']}",
            f"hugo.imaging.quality={config['imaging']['quality']}",
            f"hugo.services.googleAnalytics.id={config['services']['googleAnalytics']['id']}",
            f"hugo.languages.en.languageName={config['languages']['en']['languageName']}",
            f"hugo.markup.goldmark.renderer.unsafe={str(config['markup']['goldmark']['renderer']['unsafe']).lower()}",
            f"hugo.params.ui.feedback.yes={config['params']['ui']['feedback']['yes']}",
            f"hugo.params.links.user.0.name={config['params']['links']['user'][0]['name']}",
            f"hugo.params.links.user.0.url={config['params']['links']['user'][0]['url']}",
            f"hugo.params.links.developer.0.name={config['params']['links']['developer'][0]['name']}",
            f"hugo.params.mermaid.enable={str(config['params']['mermaid']['enable']).lower()}",
        ]
    )
    return "\n".join(rows) + "\n"


def render_precedence():
    sources = [
        (
            "defaults",
            'fallback = true\nfeatures = ["default"]\nsettings = { mode = "debug", retries = 1 }\nworkers = 2\n',
        ),
        (
            "file",
            'features = ["file"]\nsettings = { mode = "release", retries = 3 }\nworkers = 4\n',
        ),
        (
            "environment",
            'features = ["environment"]\nsettings = { mode = "ci", source = "environment" }\n',
        ),
        ("command-line", 'features = ["command-line"]\n'),
    ]
    values = {}
    provenance = {}
    for source, document in sources:
        for key, value in tomllib.loads(document).items():
            values[key] = value
            provenance[key] = source

    rows = [
        f"precedence.fallback={str(values['fallback']).lower()}@{provenance['fallback']}",
        f"precedence.workers={values['workers']}@{provenance['workers']}",
        f"precedence.features={values['features'][0]}@{provenance['features']}",
        f"precedence.settings.mode={values['settings']['mode']}@{provenance['settings']}",
        f"precedence.settings.source={values['settings']['source']}@{provenance['settings']}",
    ]
    return "\n".join(rows) + "\n"


def main(arguments):
    if arguments == ["--precedence-batch"]:
        sys.stdout.write(render_precedence())
        return 0
    if len(arguments) != 4 or arguments[0] != "--parity-batch":
        return 2
    sys.stdout.write(
        render_cargo(arguments[1])
        + render_pyproject(arguments[2])
        + render_hugo(arguments[3])
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
