#!/bin/sh
# Expose the shell's cd-maintained environment to the wrapper parity matrix.
printf '%s\000%s\000' "$PWD" "$OLDPWD"
