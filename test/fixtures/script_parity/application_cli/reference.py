#!/usr/bin/env python3
"""Independent bounded CLI contract reference for the A05 fixture."""

import sys


COMMANDS = {
    "build": {
        "description": "Build artifacts",
        "options": [
            ("--jobs", "-j", "jobs", True, "", "Worker count"),
            ("--verbose", "-v", "verbose", False, "--no-verbose", "Show verbose output"),
        ],
    },
    "test": {
        "description": "Run tests",
        "options": [
            ("--verbose", "-v", "verbose", False, "--no-verbose", "Show verbose output"),
        ],
    },
}

CASES = [
    ("attached-and-passthrough", ["build", "-j8", "-v", "src", "--", "--literal", ""]),
    ("separated-short-value", ["build", "-j", "9"]),
    ("equals-short-value", ["build", "-j=4"]),
    ("negative-boolean", ["test", "--no-verbose", "suite"]),
    ("root-help", ["--help"]),
    ("command-help", ["build", "--help"]),
    ("empty-value-over-default", ["build", "--jobs="]),
    ("missing-command", []),
    ("unknown-command", ["clean"]),
    ("unknown-option", ["build", "--wat"]),
    ("missing-value", ["build", "--jobs", "--"]),
    ("duplicate-option", ["build", "--jobs=4", "-j8"]),
    ("unexpected-boolean-value", ["test", "--verbose=true"]),
    ("build-defaults", ["build"]),
    ("test-defaults", ["test"]),
]


def root_help():
    return (
        "Usage: app <COMMAND> [OPTIONS] [ARGS...]\n\n"
        "Commands:\n"
        "  build\tBuild artifacts\n"
        "  test\tRun tests\n\n"
        "Options:\n  -h, --help\tShow this help\n"
    )


def command_help(name):
    command = COMMANDS[name]
    text = f"Usage: app {name} [OPTIONS] [ARGS...]\n\n{command['description']}\n\nOptions:\n"
    for long_name, short_name, _key, takes_value, negative_name, description in command["options"]:
        spelling = f"  {long_name}"
        if short_name:
            spelling += f", {short_name}"
        if takes_value:
            spelling += " <VALUE>"
        if negative_name:
            spelling += f", {negative_name}"
        text += f"{spelling}\t{description}\n"
    return text + "  -h, --help\tShow this help\n"


def parse_command(name, arguments):
    options = COMMANDS[name]["options"]
    values = []
    positionals = []
    enabled = True
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if enabled and argument in ("--help", "-h"):
            return ("help", values, positionals)
        if enabled and argument == "--":
            enabled = False
            index += 1
            continue
        if enabled and len(argument) > 1 and argument.startswith("-"):
            option_end = argument.find("=")
            inline_separator = option_end >= 0
            if not inline_separator:
                option_end = len(argument)
            option_name = argument[:option_end]
            if not inline_separator and len(argument) > 2 and argument.startswith("-") and not argument.startswith("--"):
                short_name = argument[:2]
                short = next((item for item in options if item[1] == short_name and item[3]), None)
                if short is not None:
                    option_name = short_name
                    option_end = 2

            match = next((item for item in options if item[0] == option_name or item[1] == option_name or item[4] == option_name and item[4]), None)
            if match is None:
                return ("unknown-option", [], [])
            long_name, short_name, key, takes_value, negative_name, _description = match
            negative = bool(negative_name and option_name == negative_name)
            inline_value = inline_separator or option_end < len(argument)
            if takes_value:
                if negative:
                    return ("invalid-schema", [], [])
                if inline_value:
                    start = option_end + 1 if inline_separator else option_end
                    value = argument[start:]
                else:
                    if index + 1 >= len(arguments) or arguments[index + 1] == "--":
                        return ("missing-value", [], [])
                    index += 1
                    value = arguments[index]
                if any(existing_key == key for existing_key, _ in values):
                    return ("duplicate-option", [], [])
                values.append((key, value))
            else:
                if inline_value:
                    return ("unexpected-value", [], [])
                if any(existing_key == key for existing_key, _ in values):
                    return ("duplicate-option", [], [])
                values.append((key, "false" if negative else "true"))
            index += 1
            continue
        positionals.append(argument)
        index += 1
    return ("ok", values, positionals)


def main(arguments):
    if not arguments:
        return ("missing-command", "", [], [])
    if arguments[0] in ("-h", "--help"):
        return ("root-help", "", [], [])
    name = arguments[0]
    if name not in COMMANDS:
        return ("unknown-command", "", [], [])
    state, values, positionals = parse_command(name, arguments[1:])
    return (state, name, values, positionals)


def evaluate(arguments):
    state, name, values, positionals = main(arguments)
    if state == "root-help":
        return (0, root_help(), "")
    if state == "help":
        return (0, command_help(name), "")
    if state != "ok":
        return (2, "", f"error={state}\n")
    resolved = {"verbose": "false"}
    if name == "build":
        resolved["jobs"] = "2"
    for key, value in values:
        resolved[key] = value
    output = f"command={name}\n"
    for key in sorted(resolved):
        value = resolved[key]
        output += f"{key}={value}\n"
    for value in positionals:
        output += f"positional={value}\n"
    return (0, output, "")


def batch():
    output = ""
    for name, arguments in CASES:
        status, stdout, stderr = evaluate(arguments)
        output += f"case={name}\nstatus={status}\nstdout-begin\n{stdout}stdout-end\nstderr-begin\n{stderr}stderr-end\n"
    return output


if __name__ == "__main__":
    arguments = sys.argv[1:]
    if arguments == ["--parity-batch"]:
        sys.stdout.write(batch())
        raise SystemExit(0)
    status, stdout, stderr = evaluate(arguments)
    sys.stdout.write(stdout)
    sys.stderr.write(stderr)
    raise SystemExit(status)
