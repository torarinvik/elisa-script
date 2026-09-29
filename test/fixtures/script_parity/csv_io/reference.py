#!/usr/bin/env python3
"""Independent Python csv oracle for the C05 parser/encoder parity slice."""

import csv
import io
import sys


CORPUS = (
    "label,note\n"
    "plain,ascii\n"
    "quoted,\"comma, quote \"\"and\"\"\"\n"
    "multiline,\"line 1\nline 2\"\n"
    "empty,\"\"\n"
    "unicode,blåbær\n"
)
MALFORMED = "\"unterminated,value\n"


def reader(source):
    return csv.reader(
        io.StringIO(source, newline=""),
        delimiter=",",
        quotechar='"',
        doublequote=True,
        strict=True,
    )


def main():
    rows = list(reader(CORPUS))
    output = io.StringIO(newline="")
    writer = csv.writer(
        output,
        delimiter=",",
        quotechar='"',
        doublequote=True,
        lineterminator="\n",
        quoting=csv.QUOTE_MINIMAL,
    )
    writer.writerows(rows)

    try:
        list(reader(MALFORMED))
    except csv.Error:
        malformed = "malformed=error"
    else:
        malformed = "malformed=accepted"

    sys.stdout.write(output.getvalue())
    sys.stdout.write(malformed + "\n")


if __name__ == "__main__":
    main()
