#!/bin/bash
# Copies the current sources next to the sim (with the Roblox stand-ins on top) and runs it.
# Usage: bash test/run_sim.sh [path to the luau binary]
here="$(cd "$(dirname "$0")" && pwd)"; L="${1:-luau}"
work="$(mktemp -d)"
cat "$here/stubs.luau" "$here/botai_sim.luau" > "$work/botai_sim.luau"
cat "$here/stubs.luau" "$here/../src/Rules__3.luau" > "$work/Rules.luau"
cat "$here/stubs.luau" "$here/../src/BotAI__BOTAI.luau" > "$work/BotAI.luau"
"$L" "$work/botai_sim.luau"
