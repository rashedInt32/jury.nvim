#!/usr/bin/env bash
# Run the jury.nvim test suite headless. No network.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nvim --headless --clean -u "$here/minimal_init.lua" -l "$here/spec.lua"
