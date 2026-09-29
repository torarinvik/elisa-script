#!/bin/sh
# Separate process-identity probe for a shell wrapper that ends in `exec`.
kill -TERM "$$"
exit 99
