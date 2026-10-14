#!/usr/bin/env bash
# Runs the HeroEngine Phase 0 offline tests with the Luau CLI (https://github.com/luau-lang/luau/releases).
# Set LUAU to the `luau` binary if it is not on PATH.
set -euo pipefail
cd "$(dirname "$0")"
"${LUAU:-luau}" run.luau
